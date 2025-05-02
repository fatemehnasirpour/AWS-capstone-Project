#!/bin/bash
# Update system packages
yum update -y

# Add MariaDB 10.5 repository
cat > /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = https://mirror.23media.com/mariadb/yum/10.5/centos7-amd64
gpgkey=https://mirror.23media.com/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

# Install Apache, PHP, MariaDB 10.5 server and client, unzip
yum install -y httpd php php-mysqlnd MariaDB-server MariaDB-client wget unzip

# Start and enable Apache and MariaDB
systemctl start httpd
systemctl enable httpd
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB (no interactive prompts)
mysql -e "UPDATE mysql.user SET Password=PASSWORD('StrongRootPassword!') WHERE User='root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

# Download and install WordPress
cd /var/www/html
wget https://wordpress.org/latest.zip
unzip latest.zip
cp -r wordpress/* .
rm -rf wordpress latest.zip

# Set permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Restart Apache
systemctl restart httpd
