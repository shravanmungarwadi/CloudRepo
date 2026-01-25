# DevOps Assignment – Full Stack Deployment

## Setup Guide

### Local Setup
1. Install Docker
2. Run:
   docker compose up --build
3. Access frontend on http://localhost:3000

## Troubleshooting

### Issue: Django container failed to start
**Cause:** Missing dependencies  
**Solution:** Added requirements.txt and rebuilt Docker image

