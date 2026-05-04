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
  timeout    = 600

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
  listener_template = {
    spec = {
      containers = [{
        name = "listener"
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "250m", memory = "256Mi" }
        }
      }]
      nodeSelector = { "node-role" = "system" }
      tolerations = [{
        key      = "CriticalAddonsOnly"
        operator = "Exists"
        effect   = "NoSchedule"
      }]
    }
  }

  # Simple template for jobs that don't need Docker (most test jobs)
  simple_template_x64 = {
    metadata = {
      annotations = { "karpenter.sh/do-not-disrupt" = "true" }
    }
    spec = {
      nodeSelector = { "valkey.io/pool" = "x64" }
      containers = [{
        name    = "runner"
        image   = "653928081447.dkr.ecr.us-east-1.amazonaws.com/valkey-runner:latest"
        command = ["/home/runner/run.sh"]
        resources = {
          requests = { cpu = "3", memory = "6Gi" }
          limits   = { cpu = "7", memory = "14Gi" }
        }
      }]
    }
  }

  simple_template_x64_largemem = {
    metadata = {
      annotations = { "karpenter.sh/do-not-disrupt" = "true" }
    }
    spec = {
      nodeSelector = { "valkey.io/pool" = "x64-largemem" }
      containers = [{
        name    = "runner"
        image   = "653928081447.dkr.ecr.us-east-1.amazonaws.com/valkey-runner:latest"
        command = ["/home/runner/run.sh"]
        resources = {
          requests = { cpu = "7", memory = "28Gi" }
          limits   = { cpu = "15", memory = "56Gi" }
        }
      }]
    }
  }

  # Dind template only for container-based jobs (rpm-distros, alpine)
  dind_template_x64 = {
    metadata = {
      annotations = { "karpenter.sh/do-not-disrupt" = "true" }
    }
    spec = {
      nodeSelector = { "valkey.io/pool" = "x64" }
      initContainers = [{
        name    = "init-dind-externals"
        image   = "ghcr.io/actions/actions-runner:latest"
        command = ["cp", "-r", "-v", "/home/runner/externals/.", "/home/runner/tmpDir/"]
        volumeMounts = [{
          name      = "dind-externals"
          mountPath = "/home/runner/tmpDir"
        }]
      }]
      containers = [
        {
          name    = "runner"
          image   = "ghcr.io/actions/actions-runner:latest"
          command = ["/home/runner/run.sh"]
          env = [
            { name = "DOCKER_HOST", value = "unix:///var/run/docker.sock" },
            { name = "RUNNER_WAIT_FOR_DOCKER_IN_SECONDS", value = "120" }
          ]
          resources = {
            requests = { cpu = "3", memory = "6Gi" }
            limits   = { cpu = "7", memory = "14Gi" }
          }
          volumeMounts = [
            { name = "work", mountPath = "/home/runner/_work" },
            { name = "dind-sock", mountPath = "/var/run" },
            { name = "dind-externals", mountPath = "/home/runner/externals" }
          ]
        },
        {
          name  = "dind"
          image = "653928081447.dkr.ecr.us-east-1.amazonaws.com/docker-hub/library/docker:dind"
          args = [
            "dockerd",
            "--host=unix:///var/run/docker.sock",
            "--group=$(DOCKER_GROUP_GID)"
          ]
          env = [{ name = "DOCKER_GROUP_GID", value = "123" }]
          securityContext = { privileged = true }
          volumeMounts = [
            { name = "work", mountPath = "/home/runner/_work" },
            { name = "dind-sock", mountPath = "/var/run" },
            { name = "dind-externals", mountPath = "/home/runner/externals" }
          ]
        }
      ]
      volumes = [
        { name = "work", emptyDir = {} },
        { name = "dind-sock", emptyDir = {} },
        { name = "dind-externals", emptyDir = {} }
      ]
    }
  }

  arm64_template = {
    metadata = {
      annotations = { "karpenter.sh/do-not-disrupt" = "true" }
    }
    spec = {
      nodeSelector = { "valkey.io/pool" = "arm64" }
      containers = [{
        name    = "runner"
        image   = "ghcr.io/actions/actions-runner:latest"
        command = ["/home/runner/run.sh"]
        resources = {
          requests = { cpu = "3", memory = "6Gi" }
          limits   = { cpu = "7", memory = "14Gi" }
        }
      }]
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

  values = [yamlencode({
    githubConfigUrl    = var.github_config_url
    githubConfigSecret = kubernetes_secret.github_app.metadata[0].name
    minRunners         = 0
    maxRunners         = 400
    runnerScaleSetName = "valkey-x64"
    template           = local.simple_template_x64
    listenerTemplate   = local.listener_template
    controllerServiceAccount = {
      namespace = kubernetes_namespace.arc_system.metadata[0].name
      name      = "arc-gha-rs-controller"
    }
  })]

  depends_on = [helm_release.arc_controller]
}

resource "helm_release" "runner_x64_largemem" {
  name       = "valkey-x64-largemem"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.10.1"
  wait       = true

  values = [yamlencode({
    githubConfigUrl    = var.github_config_url
    githubConfigSecret = kubernetes_secret.github_app.metadata[0].name
    minRunners         = 0
    maxRunners         = 100
    runnerScaleSetName = "valkey-x64-largemem"
    template           = local.simple_template_x64_largemem
    listenerTemplate   = local.listener_template
    controllerServiceAccount = {
      namespace = kubernetes_namespace.arc_system.metadata[0].name
      name      = "arc-gha-rs-controller"
    }
  })]

  depends_on = [helm_release.arc_controller]
}

resource "helm_release" "runner_arm64" {
  name       = "valkey-arm64"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.10.1"
  wait       = true

  values = [yamlencode({
    githubConfigUrl    = var.github_config_url
    githubConfigSecret = kubernetes_secret.github_app.metadata[0].name
    minRunners         = 0
    maxRunners         = 100
    runnerScaleSetName = "valkey-arm64"
    template           = local.arm64_template
    listenerTemplate   = local.listener_template
    controllerServiceAccount = {
      namespace = kubernetes_namespace.arc_system.metadata[0].name
      name      = "arc-gha-rs-controller"
    }
  })]

  depends_on = [helm_release.arc_controller]
}

resource "helm_release" "runner_x64_container" {
  name       = "valkey-x64-container"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.10.1"
  wait       = true

  values = [yamlencode({
    githubConfigUrl    = var.github_config_url
    githubConfigSecret = kubernetes_secret.github_app.metadata[0].name
    minRunners         = 0
    maxRunners         = 50
    runnerScaleSetName = "valkey-x64-container"
    template           = local.dind_template_x64
    listenerTemplate   = local.listener_template
    controllerServiceAccount = {
      namespace = kubernetes_namespace.arc_system.metadata[0].name
      name      = "arc-gha-rs-controller"
    }
  })]

  depends_on = [helm_release.arc_controller]
}
