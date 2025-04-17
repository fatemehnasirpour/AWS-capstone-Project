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

  tags = {
    Name = "web-server"
  }
}

# Creating local Db & wordpress 
resource "aws_instance" "wordpress_server" {
  ami           = "ami-087f352c165340ea1"
  instance_type = "t2.micro"
  key_name      = "vockey"
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [
    aws_security_group.web-security-group.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install apache2 mysql-server php php-mysql libapache2-mod-php -y

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
              chown -R www-data:www-data /var/www/html
              chmod -R 755 /var/www/html
              rm -rf wordpress latest.tar.gz

              # WordPress configuration
              cp wp-config-sample.php wp-config.php
              sed -i "s/database_name_here/wordpress/" wp-config.php
              sed -i "s/username_here/main/" wp-config.php
              sed -i "s/password_here/lab-password/" wp-config.php

              systemctl restart apache2
              EOF

  tags = {
    Name = "wordpress-ec2-local-db"
  }
}
