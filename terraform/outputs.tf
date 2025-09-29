output "control_plane_ipv6" {
  description = "IPv6 address of the control plane node"
  value       = hcloud_server.control_plane.ipv6_address
}

output "control_plane_private_ip" {
  description = "Private IP address of the control plane node"
  value       = one([for network in hcloud_server.control_plane.network : network.ip])
}

output "worker_ipv6_addresses" {
  description = "IPv6 addresses of worker nodes"
  value       = hcloud_server.workers[*].ipv6_address
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = [for worker in hcloud_server.workers : one([for network in worker.network : network.ip])]
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.private_key.filename
}

output "cluster_info" {
  description = "Cluster information for Ansible"
  value = {
    control_plane = {
      name       = hcloud_server.control_plane.name
      ipv6       = hcloud_server.control_plane.ipv6_address
      private_ip = one([for network in hcloud_server.control_plane.network : network.ip])
    }
    workers = [
      for i, worker in hcloud_server.workers : {
        name       = worker.name
        ipv6       = worker.ipv6_address
        private_ip = one([for network in worker.network : network.ip])
      }
    ]
    ssh_key_path = local_file.private_key.filename
  }
}