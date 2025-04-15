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
  vpc_id            = aws_vpc.wordpress.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2a”

  tags = {
    Name = "public-subnet"
  }
}