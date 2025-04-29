#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
dnf update -y
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=10.5
dnf install -y httpd mariadb105-server.x86_64 php php-mysqlnd php-json php-fpm wget tar unzip
systemctl enable --now httpd
systemctl enable --now mariadb
until mysqladmin ping &>/dev/null; do
  echo "Waiting for MariaDB to start..."
  sleep 2
done
mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
mysql -e "CREATE USER IF NOT EXISTS 'main'@'localhost' IDENTIFIED BY 'lab-password';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'main'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/
rm -rf wordpress latest.tar.gz
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
sed -i "s/username_here/main/" /var/www/html/wp-config.php
sed -i "s/password_here/lab-password/" /var/www/html/wp-config.php
systemctl restart httpd
