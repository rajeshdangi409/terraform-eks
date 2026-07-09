# Terraform EKS Project

This project provisions an Amazon EKS cluster on AWS using Terraform and demonstrates Kubernetes deployment, ingress, monitoring, and load-testing concepts in a portfolio-friendly setup.

## Project Overview

This repository showcases a complete DevOps workflow for:
- Provisioning a custom VPC and public subnets
- Creating an Amazon EKS cluster and worker node group
- Deploying the AWS Load Balancer Controller
- Exposing an NGINX application through an Application Load Balancer
- Configuring CloudWatch monitoring and SNS alerts
- Running basic CPU and memory stress workloads for observability testing

## Tech Stack

- Terraform
- AWS EKS
- Kubernetes
- Helm
- AWS Load Balancer Controller
- Amazon CloudWatch and SNS

## Repository Structure

- [eks.tf](eks.tf) — EKS cluster and node group configuration
- [vpc.tf](vpc.tf) — VPC, subnets, internet gateway, and route tables
- [iam.tf](iam.tf) — IAM roles and policies for EKS
- [aws-lb-controller.tf](aws-lb-controller.tf) — AWS Load Balancer Controller installation
- [cloudwatch.tf](cloudwatch.tf) — CloudWatch logs, alarms, dashboard, and SNS alerts
- [nginx.yaml](nginx.yaml) — Sample NGINX deployment and service
- [alb-ingress.yaml](alb-ingress.yaml) — ALB ingress configuration
- [cpu-stress-deployment.yaml](cpu-stress-deployment.yaml) — CPU stress workload
- [cpu-stress-daemonset.yaml](cpu-stress-daemonset.yaml) — DaemonSet-based CPU workload
- [memory-stress.yaml](memory-stress.yaml) — Memory stress workload

## Prerequisites

Before deploying this project, make sure you have:
- An AWS account
- AWS CLI configured with valid credentials
- Terraform installed (version 1.5 or later)
- kubectl installed
- Helm installed

## Deployment Steps

1. Clone the repository
   ```bash
   git clone <your-repo-url>
   cd terraform-eks
   ```

2. Initialize Terraform
   ```bash
   terraform init
   ```

3. Review the execution plan
   ```bash
   terraform plan
   ```

4. Apply the infrastructure
   ```bash
   terraform apply
   ```

5. Configure kubeconfig for the new cluster
   ```bash
   aws eks update-kubeconfig --name learning-cluster --region ap-south-1
   ```

6. Deploy the sample application
   ```bash
   kubectl apply -f nginx.yaml
   kubectl apply -f alb-ingress.yaml
   ```

7. Verify the deployment
   ```bash
   kubectl get pods
   kubectl get svc
   kubectl get ingress
   ```

## Monitoring and Testing

You can test the monitoring setup using the included stress manifests:

```bash
kubectl apply -f cpu-stress-deployment.yaml
kubectl apply -f memory-stress.yaml
```

This helps validate CPU and memory alerts through CloudWatch.

## Useful Commands

```bash
terraform fmt -recursive
terraform validate
kubectl get nodes
kubectl get pods -A
kubectl describe ingress nginx-alb-ingress
```
