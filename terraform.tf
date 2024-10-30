terraform {
  required_version = "~> 1.9"
  required_providers {
    assert = {
      source  = "hashicorp/assert"
      version = "0.14.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.4.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "4.4.0"
    }
  }
}
