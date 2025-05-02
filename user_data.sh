#!/bin/bash
yum update -y

# Install Apache and PHP
amazon-linux-extras enable php7.4
yum install -y httpd php php-mysqlnd php-fpm php-json php-mbstring mariadb105

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Download and configure WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/

# Set ownership and permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Create simple health check page
echo "<h1>WordPress instance is alive</h1>" > /var/www/html/index.html

# Restart Apache to load changes
systemctl restart httpd

