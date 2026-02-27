# 🚀 DevOps Assessment – Full Stack Deployment

A complete end-to-end DevOps implementation of a "Hello World" full-stack application using industry-standard practices including containerization, CI/CD automation, cloud deployment, and Infrastructure as Code.

---

## 🌐 Live Demo

> ⚠️ **Note:** This project uses AWS EC2 with Elastic IP. Infrastructure is brought up on demand to save costs. URLs below are updated each time the project is redeployed.

| Service | URL |
|---|---|
| Frontend | http://\<ELASTIC_IP\> |
| Backend API | http://\<ELASTIC_IP\>/api/hello/ |

> 📌 **Current IP:** Update this after every `terraform apply` with the new Elastic IP shown in the terminal output.

---

## 🧰 Tech Stack

| Category | Technology |
|---|---|
| Frontend | React, Vite, TypeScript |
| Backend | Django 6.0, Django REST Framework |
| Web Server | Nginx (reverse proxy) |
| Containerization | Docker, Docker Compose |
| CI/CD | GitHub Actions |
| Cloud | AWS EC2 (ap-south-1) |
| Infrastructure as Code | Terraform |
| Container Registry | Docker Hub |

---

## 🏗️ Architecture Overview

```
User (Browser)
      │
      ▼
 Nginx (Port 80)          ← Frontend Container
      │
      ├──── /            → Serves React static files
      │
      └──── /api/*       → Proxies to Django Backend
                                    │
                                    ▼
                          Django REST API (Port 8000)
                                    │
                               Docker Network
                               (appnet bridge)
```

---

## 📁 Project Structure

```
devops-assessment/
├── backend/                    # Django REST API
│   ├── config/                 # Django settings & URLs
│   ├── core/                   # App with /api/hello/ endpoint
│   ├── Dockerfile              # Multi-stage backend Docker image
│   ├── .dockerignore
│   └── requirements.txt
│
├── frontend/                   # React + Vite + TypeScript
│   ├── src/                    # React source code
│   ├── Dockerfile              # Multi-stage frontend Docker image
│   ├── nginx.conf              # Nginx reverse proxy config
│   └── .dockerignore
│
├── deploy/
│   ├── docker-compose.prod.yml # Production compose (used on EC2)
│   └── .env.prod.example       # Example environment variables
│
├── infra/
│   └── terraform/              # AWS infrastructure as code
│       ├── main.tf             # EC2, VPC, Security Group, EIP
│       ├── variables.tf        # Configurable variables
│       ├── outputs.tf          # EC2 public IP output
│       ├── provider.tf         # AWS provider config
│       ├── versions.tf         # Terraform version constraints
│       └── keys/               # SSH key pair (ec2_key.pub)
│
├── .github/
│   └── workflows/
│       └── cicd-aws-ec2.yml    # GitHub Actions CI/CD pipeline
│
├── docker-compose.yml          # Local development compose
├── DEVOPS.md                   # Detailed DevOps implementation report
└── README.md
```

---

## ⚙️ How to Run Locally

### Prerequisites
- Docker Desktop installed and running
- Git

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/shravanmungarwadi/CloudRepo.git
cd CloudRepo

# 2. Start both containers
docker-compose up --build

# 3. Open in browser
# Frontend: http://localhost:3000
# Backend:  http://localhost:8000/api/hello/
```

---

## 🐳 Docker Implementation

### Multi-Stage Builds

Both Dockerfiles use multi-stage builds to keep image sizes small:

**Backend** (`backend/Dockerfile`):
```
Stage 1 (builder) → installs Python dependencies
Stage 2 (runtime) → copies only what's needed, runs as non-root user
```

**Frontend** (`frontend/Dockerfile`):
```
Stage 1 (builder) → Node.js builds React app into static HTML/CSS/JS
Stage 2 (runtime) → Nginx serves the static files, runs as non-root user
```

### Security Practices
- ✅ Non-root users inside containers (`appuser`)
- ✅ No secrets hardcoded in Dockerfiles
- ✅ `.dockerignore` excludes `node_modules`, `.env`, `__pycache__`
- ✅ Environment variables injected at runtime via `docker-compose`

---

## 🔄 CI/CD Pipeline (GitHub Actions)

**File:** `.github/workflows/cicd-aws-ec2.yml`

**Trigger:** Every push to `main` branch

### Pipeline Stages

```
Push to main
     │
     ▼
┌─────────────────────┐
│   build-and-push    │
│                     │
│  • Build backend    │
│    Docker image     │
│  • Build frontend   │
│    Docker image     │
│  • Push both to     │
│    Docker Hub with  │
│    latest + SHA tag │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│      deploy         │
│                     │
│  • SSH into EC2     │
│  • Pull new images  │
│  • Restart with     │
│    docker compose   │
│  • Zero downtime!   │
└─────────────────────┘
```

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `EC2_HOST` | EC2 public/Elastic IP address |
| `EC2_USER` | EC2 SSH username (`ubuntu`) |
| `EC2_SSH_PRIVATE_KEY` | Private SSH key for EC2 access |

---

## 🏗️ Infrastructure as Code (Terraform)

**Directory:** `infra/terraform/`

### What Terraform Provisions

- ✅ VPC with DNS support
- ✅ Public subnet
- ✅ Internet Gateway + Route Table
- ✅ EC2 instance (Ubuntu 22.04, t3.micro)
- ✅ Security Group (ports 22, 80, 443 only)
- ✅ SSH Key Pair
- ✅ Elastic IP (toggle with `enable_eip` variable)
- ✅ Docker auto-installed via `user_data` script

### Key Variables (`variables.tf`)

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `ap-south-1` | AWS region |
| `instance_type` | `t3.micro` | EC2 instance type |
| `enable_eip` | `true` | Enable Elastic IP |
| `ssh_ingress_cidr` | `0.0.0.0/0` | Allowed SSH IPs |

### Usage

```bash
# Navigate to terraform directory
cd infra/terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Create infrastructure
terraform apply

# Destroy everything (saves costs when not in use)
terraform destroy
```

---

## 🔁 Re-deploy Guide (After terraform destroy)

When you need to bring the project back up:

```bash
# Step 1 — Create infrastructure
cd infra/terraform
terraform apply
# Note the EC2 IP shown in output

# Step 2 — Update GitHub Secret
# Go to GitHub → Settings → Secrets → Update EC2_HOST with new IP

# Step 3 — SSH into EC2 and fix Docker permissions
ssh -i infra/terraform/keys/ec2_key ubuntu@<NEW_IP>
sudo usermod -aG docker ubuntu
sudo systemctl restart docker

# Step 4 — Create app directory
sudo mkdir -p /opt/devops-assessment
sudo chown ubuntu:ubuntu /opt/devops-assessment
exit

# Step 5 — Copy compose file to server
scp -i infra/terraform/keys/ec2_key deploy/docker-compose.prod.yml ubuntu@<NEW_IP>:/opt/devops-assessment/

# Step 6 — Trigger CI/CD (any git push)
git commit --allow-empty -m "redeploy: trigger pipeline"
git push origin main

# Step 7 — App is live! 🎉
```

---

## 🛠️ Troubleshooting

### Issue 1: Docker Permission Denied on EC2
**Error:** `permission denied while trying to connect to the Docker API`
```bash
sudo usermod -aG docker ubuntu
sudo systemctl restart docker
```

### Issue 2: Frontend Shows No Data (Backend not connecting)
**Error:** Frontend loads but "Hello World" message missing
- Check `nginx.conf` has the `/api/` proxy block
- Ensure both containers are on the same Docker network (`appnet`)

### Issue 3: GitHub Actions Not Triggering
- Check if PAT token has expired (GitHub → Settings → Developer Settings → Tokens)
- Ensure workflow file is in `.github/workflows/` directory

### Issue 4: Django ALLOWED_HOSTS Error (HTTP 400)
```yaml
# In docker-compose.prod.yml, ensure:
environment:
  ALLOWED_HOSTS: "*"
```

---

## 📋 Evaluation Criteria Checklist

| Criteria | Status |
|---|---|
| Multi-stage Docker builds | ✅ |
| Non-root users in containers | ✅ |
| `.dockerignore` files | ✅ |
| No hardcoded secrets | ✅ |
| CI/CD triggers on push to main | ✅ |
| Images pushed to Docker Hub | ✅ |
| Deployed to AWS EC2 (Cloud) | ✅ |
| Terraform for infrastructure | ✅ |
| Security Group (80, 443, 22 only) | ✅ |
| DEVOPS.md documentation | ✅ |
| Troubleshooting log | ✅ |

---

## 👤 Author

**Shravan Mungarwadi**
- GitHub: [@shravanmungarwadi](https://github.com/shravanmungarwadi)
- Docker Hub: [shravanvm](https://hub.docker.com/u/shravanvm)
