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
# Creating Database Subnet Group
resource "aws_db_subnet_group" "wordpress_db_subnet_group" {
  name       = "wordpress-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet.id]  

  tags = {
    Name = "wordpress-db-subnet-group"
  }
}
# Creating RDS MySQL
resource "aws_db_instance" "wordpress_db" {
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  name                    = "wordpress"
  username                = "admin"
  password                = "2714abcde"  
  parameter_group_name    = "default.mysql8.0"
  skip_final_snapshot     = true  # true = don't take snapshot before deletion
  publicly_accessible     = true

  # Single AZ
  multi_az                = false

  # Disable automated backups
  backup_retention_period = 0  # 0 disables backups

  # Disable enhanced monitoring
  monitoring_interval     = 0

  # Networking
  vpc_security_group_ids  = [aws_security_group.web-security-group.id]
  db_subnet_group_name    = aws_db_subnet_group.wordpress-db-subnet-group.name
  availability_zone       = "us-west-2a"

  # Storage
  storage_type            = "gp2"
  storage_encrypted       = false

  tags = {
    Name = "wordpress-db"
  }
}
