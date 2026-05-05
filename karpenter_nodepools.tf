locals {
  karpenter_subnet_selector = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
  karpenter_sg_selector     = [{ tags = { "karpenter.sh/discovery" = var.cluster_name } }]
  karpenter_block_devices = [{
    deviceName = "/dev/xvda"
    ebs = {
      volumeSize          = "100Gi"
      volumeType          = "gp3"
      encrypted           = true
      deleteOnTermination = true
    }
  }]
}

resource "kubectl_manifest" "ec2nodeclass_x64" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "x64" }
    spec = {
      role                       = module.karpenter.node_iam_role_name
      amiSelectorTerms           = [{ alias = "al2023@latest" }]
      subnetSelectorTerms        = local.karpenter_subnet_selector
      securityGroupSelectorTerms = local.karpenter_sg_selector
      blockDeviceMappings        = local.karpenter_block_devices
      tags                       = var.tags
    }
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "ec2nodeclass_arm64" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata   = { name = "arm64" }
    spec = {
      role                       = module.karpenter.node_iam_role_name
      amiSelectorTerms           = [{ alias = "al2023@latest" }]
      subnetSelectorTerms        = local.karpenter_subnet_selector
      securityGroupSelectorTerms = local.karpenter_sg_selector
      blockDeviceMappings        = local.karpenter_block_devices
      tags                       = var.tags
    }
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "nodepool_x64" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "linux-x64" }
    spec = {
      template = {
        metadata = { labels = { "valkey.io/pool" = "x64" } }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "x64"
          }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = ["c7i.2xlarge", "c7i.4xlarge", "m7i.2xlarge", "m7i.4xlarge", "c6i.2xlarge", "c6i.4xlarge", "m6i.2xlarge", "m6i.4xlarge"]
            },
          ]
        }
      }
      limits = { cpu = "3200", memory = "6400Gi" }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "60s"
      }
    }
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "nodepool_x64_largemem" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "linux-x64-largemem" }
    spec = {
      template = {
        metadata = { labels = { "valkey.io/pool" = "x64-largemem" } }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "x64"
          }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = ["m7i.4xlarge", "m6i.4xlarge"]
            },
          ]
        }
      }
      limits = { cpu = "128", memory = "512Gi" }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "300s"
      }
    }
  })

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "nodepool_arm64" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata   = { name = "linux-arm64" }
    spec = {
      template = {
        metadata = { labels = { "valkey.io/pool" = "arm64" } }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "arm64"
          }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["arm64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = ["c7g.2xlarge", "c7g.4xlarge", "m7g.2xlarge", "m7g.4xlarge"]
            },
          ]
        }
      }
      limits = { cpu = "16", memory = "64Gi" }
      disruption = {
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "Never"
      }
    }
  })

  depends_on = [helm_release.karpenter]
}
