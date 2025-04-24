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
  ami           = "ami-087f352c165340ea1"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet_1.id
  key_name      = "vockey"

  vpc_security_group_ids = [
    aws_security_group.web-security-group.id
  ]

  associate_public_ip_address = true

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
  ami           = "ami-087f352c165340ea1"
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

# Create ALB
resource "aws_lb" "wordpress_alb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  tags = {
    Name = "wordpress-alb"
  }
}

resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wordpress-vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "wordpress_listener" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}

# Launch Template
resource "aws_launch_template" "wordpress_template" {
  name_prefix   = "wordpress-template"
  image_id      = "ami-087f352c165340ea1"
  instance_type = "t2.micro"
  key_name      = "vockey"

  vpc_security_group_ids = [aws_security_group.web-security-group.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "wordpress-asg-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "wordpress_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  target_group_arns    = [aws_lb_target_group.wordpress_tg.arn]
  launch_template {
    id      = aws_launch_template.wordpress_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "wordpress-asg"
    propagate_at_launch = true
  }
}

# RDS: DB Subnet Group
resource "aws_db_subnet_group" "wordpress_db_subnet_group" {
  name       = "wordpress-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "wordpress-db-subnet-group"
  }
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  description = "Allow MySQL access"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web-security-group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# RDS Instance
resource "aws_db_instance" "wordpress_db" {
  identifier              = "wordpress-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = "admin"
  password                = "lab-password"
  db_name                 = "wordpress"
  db_subnet_group_name    = aws_db_subnet_group.wordpress_db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
  multi_az                = true
  publicly_accessible     = false

  tags = {
    Name = "wordpress-db"
  }
}

# [Your existing resources... (VPC, Subnets, EC2 instances, RDS, etc.)]

# IAM Role for CloudWatch Agent
resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "cloudwatch-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach CloudWatchAgentServerPolicy to the IAM Role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy_attachment" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile for EC2 (Attach CloudWatch Role)
resource "aws_iam_instance_profile" "cloudwatch_instance_profile" {
  name = "cloudwatch-instance-profile"
  role = aws_iam_role.cloudwatch_agent_role.name
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "wordpress_log_group" {
  name              = "/wordpress/logs"
  retention_in_days = 7

  tags = {
    Name = "wordpress-log-group"
  }
}



