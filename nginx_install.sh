#!/bin/bash
# This script is used as User Data in the Launch Template.

# Update the system
sudo dnf update -y

# Install NGINX (using dnf for Amazon Linux 2023)
sudo dnf install nginx -y

# Enable NGINX to start automatically on boot
sudo systemctl enable nginx

# Start the NGINX service immediately
sudo systemctl start nginx

# Simple index file to confirm service is running
echo "<html><body><h1 style='color: #2563EB; font-family: sans-serif;'>Hello from NGINX - Served by $(hostname)!</h1><p style='font-style: italic;'>Web Tier instance successfully auto-scaled and configured.</p></body></html>" | sudo tee /usr/share/nginx/html/index.html