terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "local" {}
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "null_resource" "istio_helm_repo" {
  provisioner "local-exec" {
    command = "helm repo add istio https://istio-release.storage.googleapis.com/charts && helm repo update"
  }
}

resource "helm_release" "istio_base" {
  depends_on = [null_resource.istio_helm_repo]

  name       = "istio-base"
  repository = "istio"
  chart      = "base"
}

resource "helm_release" "istiod" {
  depends_on = [helm_release.istio_base]

  name       = "istiod"
  repository = "istio"
  chart      = "istiod"
  set {
    name  = "global.proxy.autoInject"
    value = "enabled"
  }
}

resource "helm_release" "istio_ingress" {
  depends_on = [helm_release.istiod]

  name       = "istio-ingress"
  repository = "istio"
  chart      = "ingress"

  set {
    name  = "enabled"
    value = "true"
  }
}

resource "kubernetes_deployment" "httpd" {
  metadata {
    name      = "httpd"
    namespace = "default"
    labels = {
      app = "httpd"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "httpd"
      }
    }

    template {
      metadata {
        labels = {
          app = "httpd"
        }
      }

      spec {
        container {
          name  = "httpd"
          image = "httpd:latest"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "httpd_service" {
  metadata {
    name      = "httpd-service"
    namespace = "default"
  }

  spec {
    selector = {
      app = "httpd"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_manifest" "httpd_virtual_service" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "httpd"
      namespace = "default"
    }
    spec = {
      hosts = ["httpd.local"]
      http  = [
        {
          match = [
            {
              uri = {
                prefix = "/"
              }
            }
          ]
          route = [
            {
              destination = {
                host = kubernetes_service.httpd_service.metadata[0].name
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "httpd_gateway" {
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "httpd-gateway"
      namespace = "istio-system"
    }
    spec = {
      selector = {
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = ["httpd.local"]
        }
      ]
    }
  }
}
