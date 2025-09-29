# Manual IP Configuration for Ansible

This document describes how to deploy Kubernetes using manually specified IP addresses instead of relying on Terraform to provision infrastructure.

## Use Cases

- You already have existing servers/VMs
- You're using a different cloud provider or bare metal
- You want to deploy to servers provisioned outside of Terraform
- You're testing with local VMs or a different infrastructure setup

## Prerequisites

- Servers/VMs running Debian 12 (or compatible Linux distribution)
- SSH access to all nodes with key-based authentication
- Ansible >= 2.9 installed locally
- All nodes should be accessible from your local machine

## Quick Start

### Method 1: Using the convenience script (Recommended)

```bash
# Deploy with IPv6 addresses
./deploy-manual.sh --control-plane-ip 2001:db8::1 --worker-ips 2001:db8::2,2001:db8::3

# Deploy with IPv4 addresses
./deploy-manual.sh --control-plane-ip 192.168.1.10 --worker-ips 192.168.1.11,192.168.1.12

# Use custom SSH key and user
./deploy-manual.sh \
  --control-plane-ip 10.0.1.10 \
  --worker-ips 10.0.1.11,10.0.1.12 \
  --ssh-key-path ~/.ssh/my-key \
  --ssh-user ubuntu

# Only generate inventory without deployment
./deploy-manual.sh \
  --control-plane-ip 10.0.1.10 \
  --worker-ips 10.0.1.11,10.0.1.12 \
  --inventory-only
```

### Method 2: Using Ansible directly

```bash
cd ansible

# Install requirements
ansible-galaxy collection install -r requirements.yml

# Generate inventory with manual IPs
ansible-playbook generate-inventory.yml \
  -e "manual_mode=true" \
  -e "control_plane_ip=2001:db8::1" \
  -e "worker_ips=[\"2001:db8::2\",\"2001:db8::3\"]" \
  -e "ssh_key_path=~/.ssh/id_rsa" \
  -e "ssh_user=root"

# Deploy Kubernetes
ansible-playbook site.yml
```

### Method 3: Using the dedicated manual playbook

```bash
cd ansible

# Generate inventory using the manual-specific playbook
ansible-playbook manual-inventory.yml \
  -e "control_plane_ip=192.168.1.10" \
  -e "worker_ips=[\"192.168.1.11\",\"192.168.1.12\"]" \
  -e "ssh_key_path=~/.ssh/id_rsa"

# Deploy Kubernetes
ansible-playbook site.yml
```

## Configuration Options

### Required Variables

- `control_plane_ip`: IP address (IPv4 or IPv6) of the control plane node
- `worker_ips`: List of IP addresses for worker nodes

### Optional Variables

- `ssh_key_path`: Path to SSH private key (default: `../terraform/ssh_keys/id_rsa`)
- `ssh_user`: SSH username (default: `root`)
- `manual_mode`: Set to `true` to force manual mode in `generate-inventory.yml`

## Server Requirements

### Minimum Hardware

- **Control Plane**: 2 CPU cores, 2GB RAM, 20GB storage
- **Workers**: 2 CPU cores, 2GB RAM, 20GB storage

### Operating System

- Debian 12 (recommended)
- Ubuntu 20.04+ 
- CentOS/RHEL 8+
- Other systemd-based distributions (may require minor adjustments)

### Network Requirements

- All nodes must be able to communicate with each other
- Control plane node must be accessible from your local machine on port 6443 (Kubernetes API)
- SSH access (port 22) to all nodes
- If using NodePort services, ensure ports 30000-32767 are accessible

### Pre-deployment Setup

1. **Install SSH keys on all nodes**:
   ```bash
   # Copy your public key to all nodes
   ssh-copy-id -i ~/.ssh/id_rsa.pub user@node-ip
   ```

2. **Verify connectivity**:
   ```bash
   # Test SSH access to all nodes
   ssh -i ~/.ssh/id_rsa user@control-plane-ip "echo 'Control plane accessible'"
   ssh -i ~/.ssh/id_rsa user@worker1-ip "echo 'Worker 1 accessible'"
   ssh -i ~/.ssh/id_rsa user@worker2-ip "echo 'Worker 2 accessible'"
   ```

3. **Ensure sudo access** (if not using root):
   ```bash
   # User should have passwordless sudo access
   echo 'username ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/username
   ```

## Generated Inventory Structure

The manual inventory generates a structure like this:

```yaml
all:
  vars:
    ansible_user: root
    ansible_ssh_private_key_file: "~/.ssh/id_rsa"
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    kubernetes_version: "1.33"
    pod_network_cidr: "192.168.0.0/16"
    service_cidr: "10.96.0.0/12"
    
  children:
    control_plane:
      hosts:
        control-plane:
          ansible_host: "2001:db8::1"
          node_role: master
          
    workers:
      hosts:
        worker-1:
          ansible_host: "2001:db8::2"
          node_role: worker
        worker-2:
          ansible_host: "2001:db8::3"
          node_role: worker
    
    kubernetes:
      children:
        control_plane:
        workers:
```

## Troubleshooting

### Common Issues

1. **SSH Connection Fails**:
   ```bash
   # Test SSH connectivity
   ssh -vvv -i ~/.ssh/id_rsa user@node-ip
   
   # Check if SSH agent is running
   ssh-add -l
   
   # Add key to SSH agent if needed
   ssh-add ~/.ssh/id_rsa
   ```

2. **Permission Denied (publickey)**:
   - Verify the SSH key is correct and accessible
   - Ensure the public key is in `~/.ssh/authorized_keys` on target nodes
   - Check SSH key permissions (should be 600 for private key)

3. **Inventory Not Found**:
   ```bash
   # Ensure inventory was generated
   ls -la ansible/inventory/hosts.yml
   
   # Re-generate if needed
   cd ansible && ansible-playbook generate-inventory.yml -e "manual_mode=true" ...
   ```

4. **Ansible Host Key Checking**:
   ```bash
   # Disable host key checking (already configured in ansible.cfg)
   export ANSIBLE_HOST_KEY_CHECKING=False
   ```

### Validation Commands

```bash
# Test inventory
cd ansible && ansible-inventory --list

# Test connectivity to all hosts
ansible all -m ping

# Check Ansible configuration
ansible-config dump --only-changed
```

## Integration with Existing Infrastructure

This manual mode is designed to work alongside the existing Terraform workflow. You can:

1. Use Terraform for some nodes and manual configuration for others
2. Start with manual deployment and migrate to Terraform later
3. Use manual mode for testing before committing to infrastructure provisioning

The same Ansible playbooks and roles work for both modes, ensuring consistency in your Kubernetes deployment regardless of how the infrastructure was provisioned.