provider "assert" {}

provider "http" {}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "local" {}

provider "random" {}

provider "tls" {}

resource "helm_release" "rook_ceph" {
  name             = "rook"
  version          = "1.15.4"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  namespace        = "storage"
  atomic           = true
  create_namespace = true
  lint             = true

  set {
    name  = "monitoring.enabled"
    value = true
  }

  set {
    name  = "csi.serviceMonitor.enabled"
    value = true
  }



  values = [
    file("values/rook-ceph/values.yaml")
  ]
}

resource "helm_release" "rook_ceph_cluster" {
  name             = "rook-ceph"
  version          = "1.15.4"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph-cluster"
  namespace        = "storage"
  atomic           = true
  create_namespace = true
  lint             = true

  values = [
    file("values/rook-ceph-cluster/values.yaml")
  ]

  set {
    name  = "monitoring.enabled"
    value = true
  }

  set {
    name  = "monitoring.createPrometheusRules"
    value = true
  }

  set {
    name  = "cephClusterSpec.monitoring.enabled"
    value = true
  }

  depends_on = [
    helm_release.rook_ceph
  ]
}

resource "helm_release" "prometheus" {
  name             = "prometheus"
  version          = "65.5.0"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  atomic           = true
  create_namespace = true
  lint             = true

  values = [
    file("values/prometheus/values.yaml")
  ]

  depends_on = [
    helm_release.rook_ceph,
    helm_release.rook_ceph_cluster
  ]
}

resource "helm_release" "grafana_agent" {
  name             = "grafana-agent"
  repository       = "https://grafana.github.io/helm-charts"
  version          = "0.4.4"
  chart            = "grafana-agent-operator"
  namespace        = "monitoring"
  atomic           = true
  create_namespace = true
  lint             = true

  values = [
    file("values/grafana/values.yaml")
  ]

  depends_on = [
    helm_release.prometheus
  ]
}

resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  version          = "1.16.3"
  namespace        = "kube-system"
  atomic           = true
  create_namespace = false
  lint             = true

  values = [
    file("values/cilium/values.yaml")
  ]

  depends_on = [
    helm_release.prometheus,
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.16.1"
  namespace        = "cert-manager"
  atomic           = true
  create_namespace = true
  lint             = true

  values = [
    file("values/cert-manager/values.yaml")
  ]

  depends_on = [
    helm_release.cilium,
  ]
}

resource "kubernetes_manifest" "l2_announcement" {
  manifest = {
    "apiVersion" = "cilium.io/v2alpha1"
    "kind"       = "CiliumL2AnnouncementPolicy"
    "metadata" = {
      "name" = "policy1"
    }
    "spec" = {
      "nodeSelector" = {
        "matchExpressions" = [
          {
            "key"      = "node-role.kubernetes.io/control-plane"
            "operator" = "DoesNotExist"
          }
        ]
      }
      "interfaces" = [
        "^eth[0-9]+"
      ]
      "externalIPs"     = true
      "loadBalancerIPs" = true
    }
  }

  depends_on = [
    helm_release.cilium,
  ]
}

resource "kubernetes_manifest" "lb_ip_pool" {
  manifest = {
    "apiVersion" = "cilium.io/v2alpha1"
    "kind"       = "CiliumLoadBalancerIPPool"
    "metadata" = {
      "name" = "lan-pool"
    }
    "spec" = {
      "blocks" = [
        {
          "cidr" = "192.168.1.192/27"
        }
      ]
      "disabled" = false
    }
  }

  depends_on = [
    helm_release.cilium,
  ]
}

resource "kubernetes_manifest" "loki_chunks" {
  manifest = {
    "apiVersion" = "objectbucket.io/v1alpha1"
    "kind"       = "ObjectBucketClaim"
    "metadata" = {
      "name"      = "loki-chunks"
      "namespace" = "monitoring"
    }
    "spec" = {
      "generateBucketName" = "loki-chunks"
      "storageClassName"   = "ceph-bucket"
    }
  }

  depends_on = [
    helm_release.rook_ceph_cluster,
  ]
}

resource "kubernetes_manifest" "loki_ruler" {
  manifest = {
    "apiVersion" = "objectbucket.io/v1alpha1"
    "kind"       = "ObjectBucketClaim"
    "metadata" = {
      "name"      = "loki-ruler"
      "namespace" = "monitoring"
    }
    "spec" = {
      "generateBucketName" = "loki-ruler"
      "storageClassName"   = "ceph-bucket"
    }
  }

  depends_on = [
    helm_release.rook_ceph_cluster,
  ]
}

resource "kubernetes_manifest" "loki_admin" {
  manifest = {
    "apiVersion" = "objectbucket.io/v1alpha1"
    "kind"       = "ObjectBucketClaim"
    "metadata" = {
      "name"      = "loki-admin"
      "namespace" = "monitoring"
    }
    "spec" = {
      "generateBucketName" = "loki-admin"
      "storageClassName"   = "ceph-bucket"
    }
  }

  depends_on = [
    helm_release.rook_ceph_cluster,
  ]
}

# data "kubernetes_config_map" "admin_bucket" {
#   metadata {
#     name      = kubernetes_manifest.loki_admin.object.metadata.name
#     namespace = kubernetes_manifest.loki_admin.object.metadata.namespace
#   }
# }
# 
# data "kubernetes_config_map" "ruler_bucket" {
#   metadata {
#     name      = kubernetes_manifest.loki_ruler.object.metadata.name
#     namespace = kubernetes_manifest.loki_ruler.object.metadata.namespace
#   }
# }
# 
# data "kubernetes_config_map" "chunks_bucket" {
#   metadata {
#     name      = kubernetes_manifest.loki_chunks.object.metadata.name
#     namespace = kubernetes_manifest.loki_chunks.object.metadata.namespace
#   }
# }
# 
# resource "helm_release" "loki" {
#   name             = "loki"
#   repository       = "https://grafana.github.io/helm-charts"
#   version          = "6.18.0"
#   chart            = "loki"
#   namespace        = "monitoring"
#   atomic           = true
#   create_namespace = true
#   lint             = true
# 
#   values = [
#     file("values/loki/values.yaml")
#   ]
# 
#   set {
#     name  = "loki.storage.s3.endpoint"
#     value = "${data.kubernetes_config_map.chunks_bucket.data.BUCKET_HOST}:${data.kubernetes_config_map.chunks_bucket.data.BUCKET_PORT}"
#   }
# 
#   set {
#     name  = "loki.storage.s3.accessKeyId"
#     value = base64decode(data.kubernetes_config_map.chunks_bucket.data.AWS_ACCESS_KEY_ID)
#   }
# 
#   set {
#     name  = "loki.storage.s3.secretAccessKey"
#     value = base64decode(data.kubernetes_config_map.chunks_bucket.data.AWS_SECRET_ACCESS_KEY)
#   }
# 
#   set {
#     name  = "loki.storage.bucketNames.chunks"
#     value = data.kubernetes_config_map.chunks_bucket.data.BUCKET_NAME
#   }
# 
#   set {
#     name  = "loki.storage.bucketNames.ruler"
#     value = data.kubernetes_config_map.ruler_bucket.data.BUCKET_NAME
#   }
# 
#   set {
#     name  = "loki.storage.bucketNames.admin"
#     value = data.kubernetes_config_map.admin_bucket.data.BUCKET_NAME
#   }
# 
#   depends_on = [
#     helm_release.prometheus,
#   ]
# }
