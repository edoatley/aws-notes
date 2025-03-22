#!/bin/bash

# Variables
CLUSTER_NAME=${1:-"MyEKSCluster"}
REGION="us-east-1"
NAMESPACE="mongodb"

# Update kubeconfig
echo "Updating kubeconfig for cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Verify kubectl configuration
echo "Verifying kubectl configuration"
kubectl get svc

# Install Helm if not installed
if ! command -v helm &> /dev/null
then
    echo "Helm could not be found, installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

# Add Helm repo for MongoDB
echo "Adding Helm repo for MongoDB"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create namespace for MongoDB
echo "Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE

# Deploy MongoDB using Helm
echo "Deploying MongoDB using Helm"
helm install my-mongodb bitnami/mongodb --namespace $NAMESPACE

echo "MongoDB deployment initiated. You can check the status using 'kubectl get pods -n $NAMESPACE'"