# 🛠️ Troubleshooting & Debugging Log

This document contains all real errors encountered during the DevOps Assessment project — in the **exact order they were faced** — along with root causes and fixes applied.

---

## Issue 1: Git Push Rejected Due to Large Files

**Phase:** Initial Setup

**Symptom**
```
remote: error: File .terraform/... is 150MB; exceeds GitHub's file size limit of 100MB
```

**Root Cause**
- `.terraform/` directory was accidentally committed to Git
- Terraform provider binaries are large files GitHub doesn't allow

**Fix Applied**
```bash
# Add to .gitignore
echo ".terraform/" >> .gitignore

# Remove from Git tracking
git rm -r --cached .terraform

# Commit the fix
git add .gitignore
git commit -m "fix: remove .terraform from tracking"
git push origin main
```

**Result:** ✅ Push succeeded

---

## Issue 2: Git Push Rejected — PAT Token Expired

**Phase:** Initial Setup / Any Push

**Symptom**
```
remote: Invalid username or token.
Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/...'
```

**Root Cause**
- GitHub no longer accepts passwords for Git operations
- Personal Access Token (PAT) had expired (visible in GitHub → Settings → Developer Settings → Tokens)

**Fix Applied**
1. Go to **GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (classic)**
2. Generate a new token with `repo` and `workflow` scopes
3. Update remote URL with new token:
```bash
git remote set-url origin https://<NEW_TOKEN>@github.com/<username>/<repo>.git
git push origin main
```

**Result:** ✅ Push succeeded

---

## Issue 3: Accidentally Cloned Repo Inside Project (Embedded Repository)

**Phase:** Initial Setup

**Symptom**
```
warning: adding embedded git repository: CloudRepo
hint: You've added another git repository inside your current repository
```

**Root Cause**
- `git clone` was run inside the project folder
- Created a "repo inside a repo" which Git cannot track properly

**Fix Applied**
```bash
# Force remove the embedded repo from Git tracking
git rm -rf --cached CloudRepo

# Delete the folder completely
rm -rf CloudRepo

# Commit the fix
git add .
git commit -m "fix: remove accidentally cloned embedded repo"
git push origin main
```

**Result:** ✅ Embedded repo removed, push succeeded

---

## Issue 4: GitHub Actions Not Starting — Billing Lock

**Phase:** CI/CD Setup

**Symptoms**
- GitHub Actions workflows did not start at all
- Jobs showed status: `"Account is locked due to a billing issue"`
- No pipeline logs were generated

**Root Cause**
- International transactions were disabled on the linked debit card
- GitHub could not verify billing and temporarily locked Actions

**Fix Applied**
- Enabled international transactions on the debit card
- Waited for GitHub billing verification to complete
- Manually re-ran the GitHub Actions workflow

**Result:** ✅ GitHub Actions started successfully, build and deploy stages executed

---

## Issue 5: EC2 SSH Private Key Missing

**Phase:** Infrastructure Setup

**Symptom**
```
cat: /infra/terraform/keys/ec2_key: No such file or directory
```

**Root Cause**
- Only `ec2_key.pub` (public key) existed in the repo
- The private key `ec2_key` was never generated or was lost
- Without the private key, SSH into EC2 is impossible

**Fix Applied**
```bash
# Generate a new SSH key pair directly into the keys folder
ssh-keygen -t ed25519 -C "devops-assessment-ec2" -f /d/devops-assessment/infra/terraform/keys/ec2_key
# Press Enter twice for no passphrase

# Verify both files exist
ls -la /d/devops-assessment/infra/terraform/keys/
# Should show: ec2_key  ec2_key.pub
```

Then updated the `EC2_SSH_PRIVATE_KEY` GitHub secret with the new private key content.

**Result:** ✅ SSH into EC2 worked successfully

---

## Issue 6: Docker Permission Denied on EC2 During Deployment

**Phase:** CI/CD Deployment

**Symptom**
```
permission denied while trying to connect to the Docker API
at unix:///var/run/docker.sock
```

**Root Cause**
- EC2 user (`ubuntu`) was not added to the `docker` group
- Docker socket `/var/run/docker.sock` requires group membership
- Even though Docker was installed via Terraform `user_data`, the group was not assigned

**Fix Applied**
```bash
# SSH into EC2 first
ssh -i infra/terraform/keys/ec2_key ubuntu@<EC2_IP>

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Restart Docker
sudo systemctl restart docker

# Exit and reconnect for changes to take effect
exit
```

**Result:** ✅ CI/CD deploy job ran successfully

---

## Issue 7: Deployment Succeeded But Website Shows "Connection Failed"

**Phase:** First Deployment

**Symptoms**
- GitHub Actions: ✅ Success
- Browser: ❌ `Failed to connect to the backend`
- Frontend loaded but showed no data

**Root Cause**
- Frontend React code was calling:
```
http://localhost:8000/api/hello/
```
- In production, `localhost` refers to the **user's browser**, not the EC2 server
- The request never reached Django

**Fix Applied**

Changed the frontend API call from absolute to relative path:
```javascript
// ❌ Wrong
axios.get('http://localhost:8000/api/hello/')

// ✅ Correct
axios.get('/api/hello/')
```

Nginx then handles routing `/api/` to the backend container.

**Result:** ✅ Frontend correctly calls backend through Nginx proxy

---

## Issue 8: API Works Inside EC2 But Fails Externally (HTTP 400)

**Phase:** First Deployment

**Evidence**
```bash
curl http://localhost/api/hello/     # 200 OK   ✅
curl http://<EC2_PUBLIC_IP>/api/hello/  # 400 Bad Request ❌
```

**Root Cause**
- Django `ALLOWED_HOSTS` was empty `[]` in `settings.py`
- Django blocks any request where the `Host` header is not in the allowed list
- Confirmation from Django error page:
```html
<title>DisallowedHost at /api/hello/</title>
```

**Fix Applied**

Added `ALLOWED_HOSTS` via `docker-compose.prod.yml`:
```yaml
environment:
  ALLOWED_HOSTS: "*"
  DEBUG: "0"
```

Then force-recreated the backend container:
```bash
docker compose -f docker-compose.prod.yml up -d --force-recreate backend
```

**Result:** ✅ HTTP 200 OK returned from both inside and outside EC2

---

## Issue 9: Environment Variable Set But Django Not Reading It

**Phase:** Backend Configuration

**Observation**
```bash
echo $ALLOWED_HOSTS   # Shows: *
```
But inside Django:
```python
ALLOWED_HOSTS = []    # Still empty!
```

**Root Cause**
- `settings.py` had `ALLOWED_HOSTS` hardcoded as `[]`
- Django was never reading the environment variable — it was just ignored

**Fix Applied**

Updated `backend/config/settings.py`:
```python
import os

ALLOWED_HOSTS = os.getenv("ALLOWED_HOSTS", "*").split(",")
DEBUG = os.getenv("DEBUG", "0") == "1"
```

Also ensured `docker-compose.prod.yml` passes the env vars:
```yaml
environment:
  DEBUG: "0"
  ALLOWED_HOSTS: "*"
```

**Result:** ✅ Django correctly reads environment variables at runtime

---

## Issue 10: Cannot Edit Files Inside Running Container

**Phase:** Debugging Inside Container

**Symptom**
```
vi: not found
nano: not found
sudo: not found
```

**Root Cause**
- Docker images use minimal base images (`python:3.11-slim`)
- Text editors are not installed to keep image size small
- Containers are **immutable** by design — you should NOT edit files inside them

**Important DevOps Lesson**

> ❌ Never patch a running container directly
>
> ✅ Always fix the source code → rebuild image → redeploy

**Correct Approach**
```bash
# Fix the file on your laptop
# Then push to GitHub
git add .
git commit -m "fix: update configuration"
git push origin main
# CI/CD automatically rebuilds and redeploys
```

**Result:** ✅ Understanding that containers are immutable, fixes go through CI/CD pipeline

---

## Issue 11: Nginx Not Proxying API Requests — "Hello World" Missing

**Phase:** Production Deployment

**Symptoms**
- Frontend loads ✅
- "Backend Online" badge shows ✅
- But **"Hello World from Django Backend!"** message missing ❌

**Root Cause**

`frontend/nginx.conf` was missing the `/api/` proxy block:
```nginx
# Original - missing /api/ block!
server {
    listen 80;
    location / {
        root /usr/share/nginx/html;
        try_files $uri /index.html;
    }
    # No /api/ block = Nginx doesn't know where to send API requests!
}
```

When React called `/api/hello/`, Nginx tried to serve it as a static file — which doesn't exist — so it returned nothing.

**Fix Applied**

Added the `/api/` proxy block to `frontend/nginx.conf`:
```nginx
server {
    listen 80;

    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri /index.html;
    }

    location /api/ {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Then pushed the change — CI/CD automatically rebuilt the frontend image and redeployed.

**Result:** ✅ "Hello World from Django Backend!" displayed correctly

---

## Issue 12: GitHub Actions Billing — International Transaction Block

**Phase:** CI/CD Verification

**Symptoms**
- Workflows stuck in queue
- Error: `"Account is locked due to a billing issue"`

**Root Cause**
- GitHub attempted to charge/verify the linked payment method
- Indian debit card had international transactions disabled

**Fix Applied**
- Called bank / used net banking to enable international transactions
- GitHub automatically re-verified and unlocked Actions

**Result:** ✅ Pipelines resumed running normally

---

## 📋 Summary Table

| # | Issue | Phase | Fixed? |
|---|---|---|---|
| 1 | Git push rejected — large `.terraform` files | Setup | ✅ |
| 2 | PAT token expired — auth failed | Setup | ✅ |
| 3 | Embedded repo accidentally cloned | Setup | ✅ |
| 4 | GitHub Actions billing lock | CI/CD | ✅ |
| 5 | EC2 SSH private key missing | Infrastructure | ✅ |
| 6 | Docker permission denied on EC2 | Deployment | ✅ |
| 7 | Frontend "Connection Failed" — localhost issue | Deployment | ✅ |
| 8 | HTTP 400 from external — ALLOWED_HOSTS empty | Backend | ✅ |
| 9 | Env var set but Django not reading it | Backend | ✅ |
| 10 | Cannot edit files inside container | Debugging | ✅ |
| 11 | Nginx missing `/api/` proxy block | Nginx Config | ✅ |
| 12 | GitHub Actions billing — international block | CI/CD | ✅ |

---

## 💡 Key DevOps Learnings

- **Containers are immutable** — never patch a running container, fix source code and redeploy
- **`localhost` never works in production frontend** — always use relative paths like `/api/`
- **Django `ALLOWED_HOSTS` is a common production blocker** — always set via environment variable
- **CI/CD success ≠ application success** — always verify the app in browser after deploy
- **Environment-driven configuration is mandatory** — never hardcode values, use `os.getenv()`
- **SSH keys must be backed up** — losing the private key means losing server access
- **Docker group membership** — always add deploy user to `docker` group after EC2 setup
