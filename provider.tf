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

# Creating Public Subnet in us-west-2a
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "public-subnet-1"
  }
}

# Creating Public Subnet in us-west-2b
resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "public-subnet-2"
  }
}

# Creating Route Table
resource "aws_route_table" "custom-route-table" {
  vpc_id = aws_vpc.wordpress-vpc.id

  tags = {
    Name = "custom-route-table"
  }
}

# Subnet Association with Route Table
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.custom-route-table.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.custom-route-table.id
}

# Creating Internet Gateway and attach to VPC
resource "aws_internet_gateway" "my-internet-gateway" {
  vpc_id = aws_vpc.wordpress-vpc.id

  tags = {
    Name = "my-internet-gateway"
  }
}

# Creating Route to Access the Internet
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.custom-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my-internet-gateway.id
}

# Creating Security Group
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
  subnet_id     = aws_subnet.public_subnet_1.id
  key_name      = "vockey"

  vpc_security_group_ids = [
    aws_security_group.web-security-group.id
  ]

  associate_public_ip_address = true

  # Provisioning using user_data (bash script)
  user_data = <<-EOF
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
  EOF

  tags = {
    Name = "wordpress-server"
  }
}

# Creating EC2 Instance for CLI Host in Public Subnet 2
resource "aws_instance" "cli_host" {
  ami           = "ami-087f352c165340ea1"  # Amazon Linux 2023 in us-west-2
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_2.id
  key_name      = "vockey"

  vpc_security_group_ids = [
    aws_security_group.web-security-group.id
  ]

  associate_public_ip_address = true

  tags = {
    Name = "cli-host"
  }
}
# Creating Private Subnet in us-west-2a
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "private-subnet-1"
  }
}

# Creating Private Subnet in us-west-2b
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = "10.0.40.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "private-subnet-2"
  }
}
# Define the provider
provider "aws" {
  region = "us-west-2"
}

# Create a security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
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
    Name = "alb-sg"
  }
}

# Create the ALB
resource "aws_lb" "app_alb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet.id] # Add multiple subnets for HA if needed

  tags = {
    Name = "wordpress-alb"
  }
}

# Create the Target Group
resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wordpress-vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "wordpress-target-group"
  }
}

# Create Listener for ALB
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}



