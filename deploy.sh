#!/bin/bash

set -e

echo "🚀 Deploying Kubernetes cluster on Hetzner Cloud"

# Check prerequisites
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is required but not installed"
    exit 1
fi

if ! command -v ansible &> /dev/null; then
    echo "❌ Ansible is required but not installed"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "❌ Please create terraform/terraform.tfvars from terraform/terraform.tfvars.example"
    echo "   and add your Hetzner Cloud API token"
    exit 1
fi

echo "📋 Step 1: Initializing Terraform"
cd terraform
terraform init

echo "📋 Step 2: Planning infrastructure deployment"
terraform plan

echo "📋 Step 3: Deploying infrastructure"
terraform apply -auto-approve

echo "📋 Step 4: Installing Ansible requirements"
cd ../ansible
ansible-galaxy collection install -r requirements.yml

echo "📋 Step 5: Generating Ansible inventory"
ansible-playbook generate-inventory.yml

echo "📋 Step 6: Installing Kubernetes"
ansible-playbook site.yml

echo "✅ Deployment complete!"
echo ""
echo "🔑 To access your cluster:"
echo "1. SSH to control plane:"
echo "   ssh -i terraform/ssh_keys/id_rsa root@$(cd ../terraform && terraform output -raw control_plane_ipv6)"
echo ""
echo "2. Get kubeconfig:"
echo "   sudo cat /root/.kube/config"
echo ""
echo "3. Check cluster status:"
echo "   kubectl get nodes"