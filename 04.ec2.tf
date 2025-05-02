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

 
user_data = file("${path.module}/user_data.sh")



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
