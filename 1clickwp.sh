#!/bin/bash

# Update system packages
apt update && apt upgrade -y

# Get user input for configuration
echo "Enter your domain name (example.com):"
read domain_name

echo "Enter database name for WordPress:"
read db_name

echo "Enter database username for WordPress:"
read db_user

echo "Enter a strong password for database user:"
read db_password

# Install LAMP Stack
apt install -y apache2 mysql-server php php-mysql libapache2-mod-php php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip

# Optional: Secure MySQL installation
# mysql_secure_installation 

# Create MySQL database and user
mysql -e "CREATE DATABASE $db_name;"
mysql -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';"
mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Download and configure WordPress
cd /var/www/html
wget http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
mv wordpress $domain_name
chown -R www-data:www-data /var/www/html/$domain_name
chmod -R 755 /var/www/html/$domain_name

# Generate WordPress configuration (wp-config.php)
wp config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_password --dbhost=localhost --path=/var/www/html/$domain_name

# Create Apache virtual host
cat > /etc/apache2/sites-available/$domain_name.conf << EOF
<VirtualHost *:80>
    ServerName $domain_name
    DocumentRoot /var/www/html/$domain_name

    <Directory /var/www/html/$domain_name>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

a2ensite $domain_name.conf
a2enmod rewrite
systemctl reload apache2

# --- FIREWALL CHECK  ---
echo "Checking firewall configuration..."
if ufw status | grep -q 'Status: active'; then
    echo "Firewall (ufw) is active. Opening ports 80 and 443..."
    sudo ufw allow 80 
    sudo ufw allow 443
else
    echo "Firewall is not active or not supported."
fi

# Install Certbot and set up SSL
apt install -y certbot python3-certbot-apache

# --- RETRY WITH DELAY ---
echo "Initial Certbot attempt..."
certbot --apache -d $domain_name
if [ $? -ne 0 ]; then
    echo "Certbot failed. Retrying after a short delay..."
    sleep 10 # Pause for 10 seconds
    certbot --apache -d $domain_name
fi

echo "WordPress installation complete! Visit https://$domain_name to set up your site."
