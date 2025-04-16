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

