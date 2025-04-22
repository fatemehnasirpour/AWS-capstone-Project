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

#Creating route to acsess to internet
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

# Creating EC2 Instanc
resource "aws_instance" "web_server" {
  ami           = "ami-087f352c165340ea1"  # Amazon Linux 2023 in us-west-2
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = "vockey"  

  vpc_security_group_ids = [
    aws_security_group.web-security-group.id
  ]

  associate_public_ip_address = true

 #!/bin/bash
   exec > >(sudo tee /var/log/user-data.log) 2>&1  # log output for debugging

# Update system and install necessary packages
sudo yum update -y

# Add MariaDB repository (for Amazon Linux 2 / CentOS)
sudo curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

# Install the packages
sudo yum install -y httpd mariadb php php-mysqlnd php-json php-fpm wget tar unzip

# Start and enable services
sudo systemctl enable --now httpd
sudo systemctl enable --now mariadb

# Wait for MariaDB to be ready
until mysqladmin ping &>/dev/null; do
  echo "Waiting for MariaDB to be available..."
  sleep 2
done

# Configure MariaDB for WordPress
sudo mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'main'@'localhost' IDENTIFIED BY 'lab-password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'main'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Download and extract WordPress
cd /tmp
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzf latest.tar.gz
sudo cp -r wordpress/* /var/www/html/
sudo rm -rf wordpress latest.tar.gz

# Set permissions
sudo chown -R apache:apache /var/www/html
sudo chmod -R 755 /var/www/html

# Configure wp-config.php
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sudo sed -i "s/database_name_here/wordpress/" /var/www/html/wp-config.php
sudo sed -i "s/username_here/main/" /var/www/html/wp-config.php
sudo sed -i "s/password_here/lab-password/" /var/www/html/wp-config.php

# Restart Apache
sudo systemctl restart httpd


  tags = {
    Name = "web-server"
  }
}