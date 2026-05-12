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
  version    = "0.14.1"
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

  runner_common = {
    githubConfigUrl    = var.github_config_url
    githubConfigSecret = kubernetes_secret.github_app.metadata[0].name
    listenerTemplate   = local.listener_template
    controllerServiceAccount = {
      namespace = kubernetes_namespace.arc_system.metadata[0].name
      name      = "arc-gha-rs-controller"
    }
  }
}

resource "helm_release" "runner_x64" {
  name       = "valkey-x64"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.14.1"
  wait       = true

  values = [yamlencode(merge(local.runner_common, {
    runnerScaleSetName = "valkey-x64"
    minRunners         = 0
    maxRunners         = 400
    template = {
      spec = {
        nodeSelector = { "valkey.io/pool" = "x64" }
        containers = [{
          name            = "runner"
          image           = "ghcr.io/actions/actions-runner:latest"
          command         = ["/bin/bash", "-c", "echo 'root ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null; sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null; ln -sf /usr/bin/python3 /usr/bin/python; apt-get update -qq && apt-get install -y -qq python3-pip > /dev/null 2>&1; ln -sf /usr/bin/pip3 /usr/bin/pip; /home/runner/run.sh"]
          securityContext = { runAsUser = 0 }
          env             = [{ name = "RUNNER_ALLOW_RUNASROOT", value = "1" }]
          resources       = { requests = { cpu = "4", memory = "16Gi" } }
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
  version    = "0.14.1"
  wait       = true

  values = [yamlencode(merge(local.runner_common, {
    runnerScaleSetName = "valkey-x64-largemem"
    minRunners         = 0
    maxRunners         = 200
    template = {
      spec = {
        nodeSelector = { "valkey.io/pool" = "x64-largemem" }
        containers = [{
          name            = "runner"
          image           = "ghcr.io/actions/actions-runner:latest"
          command         = ["/bin/bash", "-c", "echo 'root ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null; sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null; ln -sf /usr/bin/python3 /usr/bin/python; apt-get update -qq && apt-get install -y -qq python3-pip > /dev/null 2>&1; ln -sf /usr/bin/pip3 /usr/bin/pip; /home/runner/run.sh"]
          securityContext = { runAsUser = 0 }
          env             = [{ name = "RUNNER_ALLOW_RUNASROOT", value = "1" }]
          resources       = { requests = { cpu = "8", memory = "32Gi" } }
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
  version    = "0.14.1"
  wait       = true

  values = [yamlencode(merge(local.runner_common, {
    runnerScaleSetName = "valkey-arm64"
    minRunners         = 0
    maxRunners         = 100
    template = {
      spec = {
        nodeSelector = { "valkey.io/pool" = "arm64" }
        containers = [{
          name            = "runner"
          image           = "ghcr.io/actions/actions-runner:latest"
          command         = ["/bin/bash", "-c", "echo 'root ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null; sed -i 's|http://archive.ubuntu.com|https://archive.ubuntu.com|g; s|http://security.ubuntu.com|https://security.ubuntu.com|g' /etc/apt/sources.list 2>/dev/null; ln -sf /usr/bin/python3 /usr/bin/python; apt-get update -qq && apt-get install -y -qq python3-pip > /dev/null 2>&1; ln -sf /usr/bin/pip3 /usr/bin/pip; /home/runner/run.sh"]
          securityContext = { runAsUser = 0 }
          env             = [{ name = "RUNNER_ALLOW_RUNASROOT", value = "1" }]
          resources       = { requests = { cpu = "4", memory = "16Gi" } }
        }]
      }
    }
  }))]

  depends_on = [helm_release.arc_controller]
}
