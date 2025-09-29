# Kubernetes Infrastructure on Hetzner Cloud

This repository contains Infrastructure-as-Code (IaC) for deploying a production-ready Kubernetes cluster on Hetzner Cloud using Terraform and Ansible.

## Features

- **Multiple Deployment Options**: Use Terraform with Hetzner Cloud or manually specify IPs for existing infrastructure
- **IPv6-only Configuration**: Optimized for modern networking with IPv6 support
- **Minimal Resources**: Uses smallest possible Hetzner Cloud instances (cx22) for cost efficiency
- **Secure by Default**: Includes firewall configuration, SSH hardening, and fail2ban
- **Production Ready**: Kubernetes 1.33 with Calico CNI for networking
- **Scalable**: Easy to add/remove worker nodes
- **Cloud Agnostic**: Manual IP mode works with any cloud provider or bare metal

## Architecture

- **1 Control Plane Node**: Runs Kubernetes API server, etcd, scheduler, and controller-manager
- **2 Worker Nodes**: Run application workloads
- **Calico CNI**: Provides pod networking with IPv6 support
- **Debian 12**: Minimal and secure base OS

## Prerequisites

- Hetzner Cloud account and API token
- Terraform >= 1.0
- Ansible >= 2.9
- SSH key pair (will be generated if not provided)

## Quick Start

### Option A: Terraform + Hetzner Cloud (Automated)

#### 1. Clone and Setup

```bash
git clone <this-repo>
cd infra
```

#### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Hetzner Cloud API token
```

#### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

#### 4. Install Kubernetes

```bash
cd ../ansible

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# Generate inventory from Terraform outputs
ansible-playbook generate-inventory.yml

# Deploy Kubernetes
ansible-playbook site.yml
```

### Option B: Manual IP Specification (Existing Infrastructure)

If you already have servers or want to use a different cloud provider:

#### 1. Clone and Setup

```bash
git clone <this-repo>
cd infra
```

#### 2. Deploy with Manual IPs

```bash
# Deploy with your existing server IPs
./deploy-manual.sh --control-plane-ip YOUR_CONTROL_PLANE_IP --worker-ips WORKER1_IP,WORKER2_IP

# Example with IPv6
./deploy-manual.sh --control-plane-ip 2001:db8::1 --worker-ips 2001:db8::2,2001:db8::3

# Example with IPv4
./deploy-manual.sh --control-plane-ip 192.168.1.10 --worker-ips 192.168.1.11,192.168.1.12

# Alternative: Use a configuration file
cd ansible
cp manual-config.yml.example my-config.yml
# Edit my-config.yml with your IPs and settings
ansible-playbook generate-inventory.yml -e @my-config.yml -e "manual_mode=true"
ansible-playbook site.yml
```

For detailed manual deployment instructions, see [docs/manual-deployment.md](docs/manual-deployment.md).

### 5. Access Your Cluster

```bash
# SSH to control plane
ssh -i terraform/ssh_keys/id_rsa root@[CONTROL_PLANE_IPV6]

# Get kubectl config
sudo cat /root/.kube/config
```

## Configuration

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `hcloud_token` | Hetzner Cloud API token | Required |
| `cluster_name` | Name of the cluster | `k8s-cluster` |
| `location` | Hetzner Cloud location | `nbg1` |
| `server_type` | Server type | `cx22` |
| `worker_count` | Number of worker nodes | `2` |
| `enable_ipv4` | Enable IPv4 (false for IPv6-only) | `false` |

### Kubernetes Configuration

- **Version**: 1.33 (latest stable)
- **CNI**: Calico with IPv6 support
- **Pod Network**: `192.168.0.0/16`
- **Service Network**: `10.96.0.0/12`

## Security Features

- **Firewall**: UFW configured with minimal required ports
- **SSH**: Key-based authentication only
- **Fail2ban**: Intrusion prevention
- **Network Policies**: Calico provides micro-segmentation
- **IPv6**: Modern networking without IPv4 attack vectors

## Scaling

### Add Worker Nodes

```bash
cd terraform
# Edit terraform.tfvars to increase worker_count
terraform apply

cd ../ansible
# Regenerate inventory and run playbook
ansible-playbook generate-inventory.yml
ansible-playbook site.yml --limit workers
```

### Remove Worker Nodes

```bash
# Drain nodes first
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

cd terraform
# Decrease worker_count in terraform.tfvars
terraform apply
```

## Troubleshooting

### Check Node Status
```bash
kubectl get nodes -o wide
```

### Check Pod Network
```bash
kubectl get pods -n kube-system
```

### SSH to Nodes
```bash
ssh -i terraform/ssh_keys/id_rsa root@[NODE_IPV6]
```

### View Logs
```bash
journalctl -u kubelet -f
```

## Cost Optimization

- **cx22 instances**: ~€4.90/month per node
- **IPv6-only**: No additional IP costs
- **Minimal setup**: ~€14.70/month for full cluster

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details
