provider "hcloud" {
  token = var.hcloud_token
}

# Generate SSH key pair
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create SSH keys directory
resource "local_file" "ssh_keys_dir" {
  content  = ""
  filename = "${path.module}/ssh_keys/.gitkeep"
}

resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/ssh_keys/id_rsa"
  file_permission = "0600"
  depends_on      = [local_file.ssh_keys_dir]
}

resource "local_file" "public_key" {
  content         = tls_private_key.k8s_key.public_key_openssh
  filename        = "${path.module}/ssh_keys/id_rsa.pub"
  file_permission = "0644"
  depends_on      = [local_file.ssh_keys_dir]
}

# SSH Key Resource
resource "hcloud_ssh_key" "k8s_key" {
  name       = "${var.cluster_name}-ssh-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

# Network configuration for IPv6
resource "hcloud_network" "k8s_network" {
  name     = "${var.cluster_name}-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k8s_subnet" {
  network_id   = hcloud_network.k8s_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# Firewall for Kubernetes cluster
resource "hcloud_firewall" "k8s_firewall" {
  name = "${var.cluster_name}-firewall"

  # SSH access
  rule {
    direction = "in"
    port      = "22"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Kubernetes API server
  rule {
    direction = "in"
    port      = "6443"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # NodePort services
  rule {
    direction = "in"
    port      = "30000-32767"
    protocol  = "tcp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # etcd
  rule {
    direction = "in"
    port      = "2379-2380"
    protocol  = "tcp"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  # kubelet API
  rule {
    direction = "in"
    port      = "10250"
    protocol  = "tcp"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  # kube-scheduler
  rule {
    direction = "in"
    port      = "10259"
    protocol  = "tcp"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  # kube-controller-manager
  rule {
    direction = "in"
    port      = "10257"
    protocol  = "tcp"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  # Calico BGP
  rule {
    direction = "in"
    port      = "179"
    protocol  = "tcp"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  # Calico VXLAN
  rule {
    direction = "in"
    port      = "4789"
    protocol  = "udp"
    source_ips = [
      "10.0.0.0/16"
    ]
  }
}

# Control Plane Node
resource "hcloud_server" "control_plane" {
  name         = "${var.cluster_name}-control-plane"
  image        = var.image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.k8s_key.id]
  firewall_ids = [hcloud_firewall.k8s_firewall.id]

  public_net {
    ipv4_enabled = var.enable_ipv4
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.k8s_network.id
    ip         = "10.0.1.10"
  }

  user_data = templatefile("${path.module}/cloud-init.yml", {
    hostname = "${var.cluster_name}-control-plane"
  })

  labels = {
    role    = "control-plane"
    cluster = var.cluster_name
  }

  depends_on = [hcloud_network_subnet.k8s_subnet]
}

# Worker Nodes
resource "hcloud_server" "workers" {
  count        = var.worker_count
  name         = "${var.cluster_name}-worker-${count.index + 1}"
  image        = var.image
  server_type  = var.server_type
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.k8s_key.id]
  firewall_ids = [hcloud_firewall.k8s_firewall.id]

  public_net {
    ipv4_enabled = var.enable_ipv4
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.k8s_network.id
    ip         = "10.0.1.${20 + count.index}"
  }

  user_data = templatefile("${path.module}/cloud-init.yml", {
    hostname = "${var.cluster_name}-worker-${count.index + 1}"
  })

  labels = {
    role    = "worker"
    cluster = var.cluster_name
  }

  depends_on = [hcloud_network_subnet.k8s_subnet]
}