#!/bin/bash
yum update -y
yum install -y httpd mariadb105-server.x86_64 php php-mysqlnd php-json php-fpm wget tar unzip

# Enable and start HTTPD and MariaDB (We won’t need local MariaDB, but install MariaDB client for RDS)
systemctl start httpd
systemctl enable httpd

# Download and install WordPress
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/
rm -rf wordpress latest.tar.gz

# Set the correct permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Configure WordPress to use RDS
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php

# Modify wp-config.php to use the RDS database
sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
sed -i "s/username_here/main/" /var/www/html/wp-config.php
sed -i "s/password_here/lab-password/" /var/www/html/wp-config.php
sed -i "s/localhost/${var.rds_endpoint}/" /var/www/html/wp-config.php

# Restart HTTPD to apply the changes
systemctl restart httpd

