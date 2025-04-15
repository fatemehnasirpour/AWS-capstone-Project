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
resource “aws_subnet” “prod-subnet-public-1” {
    vpc_id = “${aws_vpc.prod-vpc.id}”
    cidr_block = “10.0.1.0/24”
    map_public_ip_on_launch = “true” //it makes this a public subnet
    availability_zone = “eu-west-2a”
    tags {
        Name = “prod-subnet-public-1”
    }
}