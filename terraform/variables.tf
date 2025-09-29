variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "k8s-cluster"
}

variable "location" {
  description = "Hetzner Cloud location"
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner Cloud server type (smallest possible)"
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "Server image"
  type        = string
  default     = "debian-12"
}



variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "enable_ipv4" {
  description = "Enable IPv4 (set to false for IPv6-only)"
  type        = bool
  default     = false
}