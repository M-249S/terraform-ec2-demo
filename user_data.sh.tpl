#!/bin/bash
# This runs once, automatically, the first time the instance boots.
# It installs Docker, then pulls and runs the Flask app image built and
# published by the companion CI/CD pipeline (devops-cicd-project on GHCR).
set -euo pipefail

apt-get update -y
apt-get install -y docker.io
systemctl enable docker
systemctl start docker

# Same hardening used when running this image locally in the Flask repo's
# own docker-compose stack: read-only root filesystem, /tmp as tmpfs, and
# the secret injected at runtime only — never baked into the image.
docker run -d \
  --name ${project_name}-app \
  --restart unless-stopped \
  -p 80:5000 \
  --read-only \
  --tmpfs /tmp \
  -e API_KEY="${app_api_key}" \
  ${docker_image}
