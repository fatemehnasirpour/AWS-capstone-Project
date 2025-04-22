provider "aws" {
  region = "us-west-2"
}

# Creating VPC
resource "aws_vpc" "wordpress-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "wordpress-vpc"
  }
}

# Creating Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "public-subnet"
  }
}

# Creating route table
resource "aws_route_table" "custom-route-table" {
  vpc_id = aws_vpc.wordpress-vpc.id

  tags = {
    Name = "custom-route-table"
  }
}

# Subnet Association with Route Table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.custom-route-table.id
}

# Creating Internet Gateway and attach to subnet
resource "aws_internet_gateway" "my-internet-gateway" {
  vpc_id = aws_vpc.wordpress-vpc.id

  tags = {
    Name = "my-internet-gateway"
  }
}

# Creating route to access the internet
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.custom-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my-internet-gateway.id
}

# Creating security Group
resource "aws_security_group" "web-security-group" {
  name        = "web-security-group"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-security-group"
  }
}

# Creating EC2 Instance for the Web Server (WordPress)
resource "aws_instance" "web_server" {
  ami           = "ami-087f352c165340ea1"  # Amazon Linux 2023 in us-west-2
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = "vockey"

  vpc_security_group_ids = [
    aws_security_group.web-security-group.id
  ]

  associate_public_ip_address = true

  # Provisioning using user_data (bash script)
 user_data = <<-EOF
  #!/bin/bash
  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

  # Update packages
  dnf update -y

  # Add MariaDB 10.5 YUM repository
  curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash -s -- --mariadb-server-version=10.5

  # Install necessary packages
  dnf install -y httpd mariadb-server php php-mysqlnd php-json php-fpm wget tar unzip

  # Start services
  systemctl enable --now httpd
  systemctl enable --now mariadb

  # Wait for MariaDB to be available
  until mysqladmin ping &>/dev/null; do
    echo "Waiting for MariaDB to start..."
    sleep 2
  done

  # Set up the database
  mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
  mysql -e "CREATE USER IF NOT EXISTS 'main'@'localhost' IDENTIFIED BY 'lab-password';"
  mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'main'@'localhost';"
  mysql -e "FLUSH PRIVILEGES;"

  # Install WordPress
  cd /tmp
  wget https://wordpress.org/latest.tar.gz
  tar -xzf latest.tar.gz
  cp -r wordpress/* /var/www/html/
  rm -rf wordpress latest.tar.gz

  # Set permissions
  chown -R apache:apache /var/www/html
  chmod -R 755 /var/www/html

  # Configure WordPress
  cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
  sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
  sed -i "s/username_here/main/" /var/www/html/wp-config.php
  sed -i "s/password_here/lab-password/" /var/www/html/wp-config.php

  # Restart Apache
  systemctl restart httpd
EOF


  tags = {
    Name = "wordpress-server"
  }
}
