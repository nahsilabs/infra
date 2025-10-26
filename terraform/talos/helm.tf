resource "helm_release" "cilium" {
  name       = "cilium"
  chart      = "cilium"
  repository = "https://helm.cilium.io/"
  namespace  = "kube-system"
  version    = "1.17.5"
  wait       = true

  values = [
    file("${path.module}/templates/cilium.yml")
  ]
}

resource "helm_release" "flux" {
  depends_on       = [helm_release.cilium]
  name             = "flux"
  chart            = "flux2"
  repository       = "https://fluxcd-community.github.io/helm-charts/"
  namespace        = "flux-system"
  version          = "2.17.0"
  create_namespace = true
  wait             = true

  set {
    name  = "notificationController.create"
    value = "false"
  }

  set {
    name  = "imageReflectionController.create"
    value = "false"
  }

  set {
    name  = "imageAutomationController.create"
    value = "false"
  }
}

resource "helm_release" "flux-sync" {
  depends_on = [helm_release.flux]
  name       = "infra"
  chart      = "flux2-sync"
  repository = "https://fluxcd-community.github.io/helm-charts/"
  namespace  = "flux-system"
  version    = "1.14.0"
  wait       = true

  values = [
    templatefile("${path.module}/templates/flux-sync.yml", {
      variables = var.flux_variables
    })
  ]
}
