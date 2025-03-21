#!/bin/bash

echo "🔥 Custom Hosting Panel Installation Started..."

# Get Domain/Subdomain Input
read -p "Enter the domain/subdomain for your panel (e.g., panel.example.com): " PANEL_DOMAIN

# Verify DNS
echo "⚡ Verifying DNS..."
if ! host $PANEL_DOMAIN > /dev/null; then
    echo "❌ DNS not configured correctly. Please point your domain to this server before continuing."
    exit 1
fi

# Get Database Credentials
read -p "Enter MySQL Database Name: " DB_NAME
read -p "Enter MySQL Username: " DB_USER
read -s -p "Enter MySQL Password: " DB_PASS
echo ""

# Get Admin User Credentials
read -p "Enter Admin Username: " ADMIN_USER
read -s -p "Enter Admin Password: " ADMIN_PASS
echo ""

# Update & install dependencies
apt update && apt upgrade -y
apt install -y curl wget sudo unzip ufw mysql-server golang nginx certbot python3-certbot-nginx

# Setup MySQL
echo "⚡ Setting up MySQL..."
systemctl start mysql
mysql -e "CREATE DATABASE $DB_NAME;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Install Backend
echo "⚡ Installing Backend..."
mkdir -p /opt/custom-panel/backend
cd /opt/custom-panel/backend
wget [BACKEND_BINARY_URL] -O panel-backend
chmod +x panel-backend

# Install Frontend
echo "⚡ Installing Frontend..."
mkdir -p /var/www/custom-panel
cd /var/www/custom-panel
wget [FRONTEND_BUILD_URL] -O frontend.zip
unzip frontend.zip && rm frontend.zip

# Configure Nginx
echo "⚡ Configuring Nginx..."
cat > /etc/nginx/sites-available/custom-panel <<EOF
server {
    listen 80;
    server_name $PANEL_DOMAIN;

    location / {
        root /var/www/custom-panel;
        index index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8080/;
    }
}
EOF

ln -s /etc/nginx/sites-available/custom-panel /etc/nginx/sites-enabled/
systemctl restart nginx

# Enable Firewall & SSL
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# Install SSL Certificate with Auto-Renew
echo "⚡ Installing Let's Encrypt SSL..."
certbot --nginx -d $PANEL_DOMAIN --agree-tos --email admin@$PANEL_DOMAIN --redirect --non-interactive
echo "🔁 Setting up Auto-Renewal for SSL..."
echo "0 0 * * * certbot renew --quiet" >> /etc/crontab

# Store Admin Credentials Securely
echo "Admin Username: $ADMIN_USER" > /opt/custom-panel/admin_credentials.txt
echo "Admin Password: $ADMIN_PASS" >> /opt/custom-panel/admin_credentials.txt
chmod 600 /opt/custom-panel/admin_credentials.txt

# Start Backend
echo "⚡ Starting Backend..."
nohup /opt/custom-panel/backend/panel-backend > /dev/null 2>&1 &

# Display Panel Access Info
echo "🎉 Custom Hosting Panel Installed Successfully!"
echo "🔗 Access your panel at: https://$PANEL_DOMAIN"
echo "🔐 Admin credentials stored at: /opt/custom-panel/admin_credentials.txt"
