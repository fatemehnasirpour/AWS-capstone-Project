#!/bin/bash
# Install updates and tools
yum update -y
yum install -y stress-ng httpd mysql wget

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Enable PHP 7.4
amazon-linux-extras enable php7.4
yum clean metadata
yum install -y php php-cli php-pdo php-fpm php-json php-mysqlnd

# Set MySQL root password
mysqladmin -u root password 'rootpassword'

# Download and setup WordPress
wget http://wordpress.org/latest.tar.gz -P /var/www/html/
cd /var/www/html
tar -zxvf latest.tar.gz
cp -rvf wordpress/* .
rm -R wordpress latest.tar.gz

# Set WordPress config
cp wp-config-sample.php wp-config.php
sed -i "s/'database_name_here'/'${db_name}'/g" wp-config.php
sed -i "s/'username_here'/'${db_user}'/g" wp-config.php
sed -i "s/'password_here'/'${db_password}'/g" wp-config.php
sed -i "s/'localhost'/'${rds_endpoint}'/g" wp-config.php

# Test DB connection
mysql -h "${rds_endpoint}" -u "${db_user}" -p"${db_password}" "${db_name}" -e "SHOW DATABASES;"

# Restart Apache
systemctl restart httpd

