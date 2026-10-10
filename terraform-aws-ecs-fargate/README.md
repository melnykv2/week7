# terraform-aws-ecs-fargate

Infrastructure for running the Healthchecks Django app on **AWS ECS Fargate** with **RDS Postgres**, behind an **Application Load Balancer**. The container image is stored in **Amazon ECR**.

```
Internet ─80─► ALB (public subnets) ─8000─► Fargate task (private subnets)
                                              │  migrate → gunicorn
                                              ├─5432─► RDS Postgres 17 (private subnets)
                                              └──────► Regional NAT Gateway ─► internet
```

## Files

| File | Contents |
|------|----------|
| `providers.tf` | AWS and random providers, region, default tags |
| `variables.tf` | Region, names, CIDRs, DB settings, image tag |
| `vpc.tf` | VPC, public/private subnets, Internet Gateway, regional NAT Gateway, route tables |
| `security_groups.tf` | Security groups for the ALB, ECS tasks and the database |
| `alb.tf` | Load balancer, target group (health check `/api/v1/status/`), HTTP listener |
| `db.tf` | RDS Postgres instance and DB subnet group |
| `iam.tf` | ECS task execution role and permission to read the app secrets |
| `ecs.tf` | ECR repository, ECS cluster, Django `SECRET_KEY` (SSM), task definition, service |
| `outputs.tf` | ECR URL, DB endpoint, DB secret ARN, ALB DNS name |
| `Dockerfile` | Multi-stage image build (build context = repository root) |


## Deployment

The ECS service needs the image to **already exist in ECR** when it starts. ECR is part of this Terraform configuration, so deployment happens in three steps:

**1. Apply only the ECR repository → 2. Build and push the image → 3. Apply everything else.**

### 1. Create the ECR repository

```bash
cd terraform-aws-ecs-fargate
terraform init
terraform apply -target=aws_ecr_repository.app
```

### 2. Build and push the image

Run the build from the **repository root**:

```bash
cd ..
docker build --platform linux/amd64 \
  -f terraform-aws-ecs-fargate/Dockerfile -t healthchecks:v3 .

cd terraform-aws-ecs-fargate
REPO=$(terraform output -raw ecr_repository_url)

aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin "${REPO%%/*}"

docker tag healthchecks:v3 "${REPO}:v3"
docker push "${REPO}:v3"
```


### 3. Deploy the rest of the infrastructure

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

## Testing

```bash
URL="http://$(terraform output -raw alb_dns_name)"

curl -i "$URL/api/v1/status/"                          # 200 OK  → app is up and can reach the DB
curl -i -H "X-Api-Key: wrong" "$URL/api/v1/checks/"    # 401     → migrations ran (tables exist)
open "$URL"                                             # styled page → static files are served
```
