resource "kubernetes_namespace" "arc_system" {
  metadata { name = "arc-system" }
}

resource "kubernetes_namespace" "arc_runners" {
  metadata { name = "arc-runners" }
}

resource "kubernetes_secret" "github_app" {
  metadata {
    name      = "github-app-secret"
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }

  data = {
    github_app_id              = var.github_app_id
    github_app_installation_id = var.github_app_installation_id
    github_app_private_key     = var.github_app_private_key
  }
}

resource "helm_release" "arc_controller" {
  name       = "arc"
  namespace  = kubernetes_namespace.arc_system.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = "0.10.1"
  wait       = true

  values = [yamlencode({
    tolerations = [{
      key      = "CriticalAddonsOnly"
      operator = "Exists"
      effect   = "NoSchedule"
    }]
    nodeSelector = { "node-role" = "system" }
  })]
}

locals {
  arc_common = {
    githubConfigUrl    = var.github_config_url
    githubConfigSecret = kubernetes_secret.github_app.metadata[0].name
  }

  listener_template = {
    spec = {
      containers = [{
        name = "listener"
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "250m", memory = "256Mi" }
        }
      }]
      tolerations = [{
        key      = "CriticalAddonsOnly"
        operator = "Exists"
        effect   = "NoSchedule"
      }]
      nodeSelector = { "node-role" = "system" }
    }
  }
}

resource "helm_release" "runner_x64" {
  name       = "valkey-x64"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.10.1"
  wait       = true

  values = [yamlencode(merge(local.arc_common, {
    runnerScaleSetName = "valkey-x64"
    minRunners         = 0
    maxRunners         = 40
    containerMode      = { type = "dind" }
    listenerTemplate   = local.listener_template
    template = {
      spec = {
        nodeSelector = { "valkey.io/pool" = "x64" }
        containers = [{
          name  = "runner"
          image = "ghcr.io/actions/actions-runner:latest"
          resources = {
            requests = { cpu = "3", memory = "6Gi" }
            limits   = { cpu = "7", memory = "14Gi" }
          }
        }]
      }
    }
  }))]

  depends_on = [helm_release.arc_controller]
}

resource "helm_release" "runner_x64_largemem" {
  name       = "valkey-x64-largemem"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.10.1"
  wait       = true

  values = [yamlencode(merge(local.arc_common, {
    runnerScaleSetName = "valkey-x64-largemem"
    minRunners         = 0
    maxRunners         = 10
    containerMode      = { type = "dind" }
    listenerTemplate   = local.listener_template
    template = {
      spec = {
        nodeSelector = { "valkey.io/pool" = "x64-largemem" }
        containers = [{
          name  = "runner"
          image = "ghcr.io/actions/actions-runner:latest"
          resources = {
            requests = { cpu = "7", memory = "28Gi" }
            limits   = { cpu = "15", memory = "56Gi" }
          }
        }]
      }
    }
  }))]

  depends_on = [helm_release.arc_controller]
}

resource "helm_release" "runner_arm64" {
  name       = "valkey-arm64"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.10.1"
  wait       = true

  values = [yamlencode(merge(local.arc_common, {
    runnerScaleSetName = "valkey-arm64"
    minRunners         = 0
    maxRunners         = 2
    listenerTemplate   = local.listener_template
    template = {
      metadata = {
        annotations = { "karpenter.sh/do-not-disrupt" = "true" }
      }
      spec = {
        nodeSelector = { "valkey.io/pool" = "arm64" }
        containers = [{
          name  = "runner"
          image = "ghcr.io/actions/actions-runner:latest"
          resources = {
            requests = { cpu = "3", memory = "6Gi" }
            limits   = { cpu = "7", memory = "14Gi" }
          }
        }]
      }
    }
  }))]

  depends_on = [helm_release.arc_controller]
}
