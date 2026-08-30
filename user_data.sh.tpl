#!/bin/bash
# This runs once, automatically, the first time the instance boots.
# It installs nginx and serves a small confirmation page — proof that
# Terraform didn't just create an empty server, but a working one.
set -euo pipefail

apt-get update -y
apt-get install -y nginx

cat > /var/www/html/index.html << HTML
<!DOCTYPE html>
<html>
<head><title>${project_name}</title></head>
<body style="font-family: sans-serif; text-align: center; margin-top: 10%;">
  <h1>It's alive!</h1>
  <p>This EC2 instance was provisioned entirely by Terraform.</p>
  <p><strong>Project:</strong> ${project_name}</p>
  <p><strong>Provisioned at:</strong> $(date -u +"%Y-%m-%d %H:%M:%S UTC")</p>
</body>
</html>
HTML

systemctl enable nginx
systemctl restart nginx
