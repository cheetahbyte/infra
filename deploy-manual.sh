#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"

# Default values
SSH_KEY_PATH="../terraform/ssh_keys/id_rsa"
SSH_USER="root"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy Kubernetes using manually specified IP addresses"
    echo ""
    echo "Required:"
    echo "  --control-plane-ip IP    IPv4 or IPv6 address of control plane node"
    echo "  --worker-ips IP1,IP2,... Comma-separated list of worker node IPs"
    echo ""
    echo "Optional:"
    echo "  --ssh-key-path PATH      Path to SSH private key (default: $SSH_KEY_PATH)"
    echo "  --ssh-user USER          SSH user (default: $SSH_USER)"
    echo "  --inventory-only         Only generate inventory, don't run deployment"
    echo "  --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy with IPv6 addresses"
    echo "  $0 --control-plane-ip 2001:db8::1 --worker-ips 2001:db8::2,2001:db8::3"
    echo ""
    echo "  # Deploy with IPv4 addresses and custom SSH key"
    echo "  $0 --control-plane-ip 192.168.1.10 --worker-ips 192.168.1.11,192.168.1.12 --ssh-key-path ~/.ssh/custom_key"
    echo ""
    echo "  # Only generate inventory without deployment"
    echo "  $0 --control-plane-ip 10.0.1.10 --worker-ips 10.0.1.11,10.0.1.12 --inventory-only"
}

# Parse command line arguments
CONTROL_PLANE_IP=""
WORKER_IPS=""
INVENTORY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --control-plane-ip)
            CONTROL_PLANE_IP="$2"
            shift 2
            ;;
        --worker-ips)
            WORKER_IPS="$2"
            shift 2
            ;;
        --ssh-key-path)
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --ssh-user)
            SSH_USER="$2"
            shift 2
            ;;
        --inventory-only)
            INVENTORY_ONLY=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$CONTROL_PLANE_IP" ]; then
    echo "❌ Error: --control-plane-ip is required"
    usage
    exit 1
fi

if [ -z "$WORKER_IPS" ]; then
    echo "❌ Error: --worker-ips is required"
    usage
    exit 1
fi

# Convert comma-separated worker IPs to YAML list format
IFS=',' read -ra WORKER_ARRAY <<< "$WORKER_IPS"
WORKER_YAML_LIST="["
for i in "${!WORKER_ARRAY[@]}"; do
    if [ $i -gt 0 ]; then
        WORKER_YAML_LIST+=","
    fi
    WORKER_YAML_LIST+="\"${WORKER_ARRAY[$i]}\""
done
WORKER_YAML_LIST+="]"

echo "🚀 Deploying Kubernetes with manually specified IPs"
echo ""
echo "📋 Configuration:"
echo "   Control Plane: $CONTROL_PLANE_IP"
echo "   Workers: ${WORKER_ARRAY[*]}"
echo "   SSH Key: $SSH_KEY_PATH"
echo "   SSH User: $SSH_USER"
echo ""

# Check prerequisites
if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible is required but not installed"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "❌ SSH key file $SSH_KEY_PATH does not exist"
    echo "   You can specify a different key with --ssh-key-path"
    exit 1
fi

# Change to ansible directory
cd "$ANSIBLE_DIR"

echo "📋 Step 1: Installing Ansible requirements"
ansible-galaxy collection install -r requirements.yml

echo "📋 Step 2: Generating inventory with manual IPs"
ansible-playbook generate-inventory.yml \
    -e "manual_mode=true" \
    -e "control_plane_ip=$CONTROL_PLANE_IP" \
    -e "worker_ips=$WORKER_YAML_LIST" \
    -e "ssh_key_path=$SSH_KEY_PATH" \
    -e "ssh_user=$SSH_USER"

if [ "$INVENTORY_ONLY" = true ]; then
    echo "✅ Inventory generation complete!"
    echo ""
    echo "📋 Generated inventory file: ansible/inventory/hosts.yml"
    echo "🔍 You can review the inventory with:"
    echo "   cat ansible/inventory/hosts.yml"
    echo ""
    echo "🚀 To deploy Kubernetes with this inventory, run:"
    echo "   cd ansible && ansible-playbook site.yml"
else
    echo "📋 Step 3: Deploying Kubernetes"
    ansible-playbook site.yml

    echo "✅ Deployment complete!"
    echo ""
    echo "🔑 To access your cluster:"
    echo "1. SSH to control plane:"
    echo "   ssh -i $SSH_KEY_PATH $SSH_USER@$CONTROL_PLANE_IP"
    echo ""
    echo "2. Get kubeconfig:"
    echo "   sudo cat /root/.kube/config"
    echo ""
    echo "3. Check cluster status:"
    echo "   kubectl get nodes"
fi