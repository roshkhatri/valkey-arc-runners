variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "valkey-ci"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "github_config_url" {
  description = "GitHub repository URL for the runner configuration"
  type        = string
  default     = "https://github.com/valkey-io/valkey"
}

variable "github_app_id" {
  description = "GitHub App ID for ARC authentication"
  type        = string
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID for ARC authentication"
  type        = string
  sensitive   = true
}

variable "github_app_private_key" {
  description = "GitHub App private key (PEM format) for ARC authentication"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = { Project = "valkey-ci" }
}
