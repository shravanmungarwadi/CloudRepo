# DevOps Implementation Report

## 1. Overview

This repository demonstrates an end-to-end DevOps implementation for a full-stack application using modern DevOps practices.  
The project covers infrastructure provisioning, containerization, CI/CD automation, deployment, and troubleshooting.

The application consists of:
- A Django REST API backend
- A React (Vite + TypeScript) frontend
- Nginx as a reverse proxy
- Docker & Docker Compose for container orchestration
- GitHub Actions for CI/CD
- AWS EC2 provisioned using Terraform

---

## 2. Architecture Overview

### High-Level Architecture

User → Nginx (Frontend Container) → Django Backend Container  
                                     ↓  
                                Docker Bridge Network  

### Components

- **Frontend**
  - React + Vite
  - Served via Nginx
  - Proxies `/api/*` requests to backend

- **Backend**
  - Django REST API
  - Exposes `/api/hello/` endpoint

- **Networking**
  - Docker bridge network (`appnet`)
  - Service-to-service communication via container names

---

## 3. Containerization Strategy

### Docker Best Practices Used

- Separate Dockerfiles for frontend and backend
- Multi-stage builds to reduce image size
- Containers run as non-root users
- `.dockerignore` used to exclude:
  - `.env` files
  - `node_modules`
  - Python cache files

### Security Considerations

- Secrets are **never committed** to GitHub
- Environment variables injected at runtime via `docker-compose`
- No sensitive data baked into Docker images

---

## 4. CI/CD Pipeline (GitHub Actions)

### Workflow Trigger
- Triggered on push to `main` branch

### Pipeline Stages

1. **Build**
   - Build frontend and backend Docker images
   - Tag images with `latest`

2. **Push**
   - Push images to Docker Hub
   - Authentication handled using GitHub Secrets

3. **Deploy**
   - SSH into EC2 using `appleboy/ssh-action`
   - Pull latest images
   - Recreate containers using `docker-compose`

### Key Benefits
- Fully automated deployment
- No manual intervention after code push
- Reproducible and consistent builds

---

## 5. Infrastructure as Code (Terraform)

Terraform provisions:
- AWS EC2 instance
- Security Group with ports:
  - 22 (SSH)
  - 80 (HTTP)
- SSH key pair for secure access

### Benefits
- Infrastructure is version-controlled
- Easy to recreate or destroy environments
- Consistent cloud setup

---

## 6. Troubleshooting & Debugging Log

### Issue 1: Git push rejected due to large files
**Cause**
- `.terraform` directory committed accidentally

**Fix**
- Added `.terraform/` to `.gitignore`
- Removed cached files using:
  ```bash
  git rm -r --cached .terraform

### Issue 2: GitHub Actions Not Starting Due to Billing Lock

**Symptoms**
- GitHub Actions workflows did not start
- Jobs showed status: *“Account is locked due to a billing issue”*
- No pipeline logs were generated

**Root Cause**
- International transactions were disabled on the linked debit card
- GitHub could not verify billing, temporarily locking Actions

**Fix Applied**
- Enabled international transactions on the debit card
- Waited for GitHub billing verification to complete
- Manually re-ran the GitHub Actions workflow

**Verification**
- GitHub Actions jobs started successfully
- Build and deploy stages executed without billing errors

---

### Issue 3: Docker Permission Denied on EC2 During Deployment

**Symptoms**
- CI/CD deploy job failed on EC2
- Docker commands returned:

**Root Cause**
- EC2 user (`ubuntu`) was not added to the `docker` group
- Docker socket (`/var/run/docker.sock`) required elevated permissions

**Fix Applied**
```bash
sudo usermod -aG docker ubuntu
sudo systemctl restart docker
```

### Issue 4: Frontend Showing “Connection Failed” Despite Backend Running

**Symptoms**
- Frontend UI loaded successfully
- Backend container was running
- API requests returned HTTP 400 Bad Request
- Browser displayed: “Failed to connect to the backend”

**Root Cause**
- Django ALLOWED_HOSTS was empty ([])
- Requests coming through Nginx proxy were rejected
- Environment variables were not correctly applied at runtime

**Fix Applied**
- Passed ALLOWED_HOSTS=* via docker-compose.prod.yml
- Ensured backend reads environment variables at container startup
- Recreated the backend container
            bash : docker compose -f docker-compose.prod.yml up -d --force-recreate backend
   Verification--> bash : curl http://localhost/api/hello/

###Result

**HTTP 200 OK returned**
- Frontend successfully displayed:
- Hello World from Django Backend!
