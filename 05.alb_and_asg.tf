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
  enable_deletion_protection = false
  tags = {
    Name = "wordpress-alb"
  }
}

resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wordpress-vpc.id 
 

  target_type = "instance"            

 }

resource "aws_lb_target_group_attachment" "wordpress-tg_attachment" {
  target_group_arn = aws_lb_target_group.wordpress_tg.arn
  
  target_id        = aws_instance.web_server.id
  port             = 80
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
  network_interfaces {
    associate_public_ip_address = true
  }

  # Use a dynamic variable in user_data to pass the RDS endpoint
 #user_data = base64encode(templatefile("${path.module}/user_data.sh", {
  #rds_endpoint = aws_db_instance.wordpress_db.endpoint
#}))

  user_data = base64encode(data.template_file.userdataEC.rendered)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "wordpress-asg-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "wordpress_asg" {
  depends_on = [aws_db_instance.wordpress_db]
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  target_group_arns    = [aws_lb_target_group.wordpress_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
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

data "template_file" "userdataEC" {
  template = file("user_data.sh")
} 
