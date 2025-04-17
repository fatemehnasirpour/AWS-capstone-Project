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

  user_data = <<EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd mariadb105-server php php-mysqli php-json php-fpm wget tar

              # Start Apache and MariaDB
              systemctl enable httpd
              systemctl start httpd
              systemctl enable mariadb
              systemctl start mariadb

              # MySQL setup
              mysql -e "CREATE DATABASE wordpress;"
              mysql -e "CREATE USER 'main'@'localhost' IDENTIFIED BY 'lab-password';"
              mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'main'@'localhost';"
              mysql -e "FLUSH PRIVILEGES;"

              # WordPress installation
              cd /var/www/html
              wget https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz
              cp -r wordpress/* .
              chown -R apache:apache /var/www/html
              chmod -R 755 /var/www/html
              rm -rf wordpress latest.tar.gz

              # WordPress configuration
              cp wp-config-sample.php wp-config.php
              sed -i "s/database_name_here/wordpress/" wp-config.php
              sed -i "s/username_here/main/" wp-config.php
              sed -i "s/password_here/lab-password/" wp-config.php

              systemctl restart httpd
            EOF


  tags = {
    Name = "web-server"
  }
}