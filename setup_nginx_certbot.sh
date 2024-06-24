#!/bin/bash

# Prompt the user for the hostname and port
read -p "Enter the hostname (e.g., clipboard.lsjbot.cc): " HOSTNAME
read -p "Enter the port your application is running on (e.g., 5666): " PORT

# Update and install necessary packages
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

# Create an Nginx configuration file for the site
NGINX_CONF="/etc/nginx/sites-available/$HOSTNAME"
sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    listen 80;
    server_name $HOSTNAME;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Create a symbolic link to enable the site
sudo ln -s /etc/nginx/sites-available/$HOSTNAME /etc/nginx/sites-enabled/

# Test the Nginx configuration
sudo nginx -t

# Restart Nginx to apply the changes
sudo systemctl restart nginx

# Obtain SSL certificates with Certbot
sudo certbot --nginx -d $HOSTNAME

# Update Nginx configuration for SSL
sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    if (\$host = $HOSTNAME) {
        return 301 https://\$host\$request_uri;
    }

    listen 80;
    server_name $HOSTNAME;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name $HOSTNAME;

    ssl_certificate /etc/letsencrypt/live/$HOSTNAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$HOSTNAME/privkey.pem;

    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Test the Nginx configuration again
sudo nginx -t

# Restart Nginx to apply the SSL changes
sudo systemctl restart nginx

echo "Setup complete. Your site should be available at https://$HOSTNAME"
