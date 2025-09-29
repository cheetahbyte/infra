#!/bin/bash

set -e

echo "🧹 Destroying Kubernetes cluster and infrastructure"

# Confirm destruction
echo "⚠️  This will permanently destroy all resources!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Destruction cancelled"
    exit 1
fi

echo "📋 Step 1: Destroying infrastructure"
cd terraform
terraform destroy -auto-approve

echo "📋 Step 2: Cleaning up SSH keys"
rm -rf ssh_keys/

echo "📋 Step 3: Cleaning up Ansible inventory"
cd ../ansible
rm -f inventory/hosts.yml

echo "✅ Cleanup complete!"