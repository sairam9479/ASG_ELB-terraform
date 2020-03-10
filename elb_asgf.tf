provider "aws" {
  region     = "us-east-2"
}

###asg
resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "lc_confg"
  image_id      = "ami-099cfc8856fdce3b7"
  instance_type = "t2.micro"
  security_groups    = ["sg-093299b047c5d6dfd"]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "launch_confg" {
  name                 = "terraform-asg"
  health_check_type    = "EC2"
  launch_configuration = "${aws_launch_configuration.as_conf.name}"
  vpc_zone_identifier  = ["subnet-f8327d82", "subnet-a75948cf", "subnet-0166d14d"]
  min_size             = 2
  max_size             = 4

  lifecycle {
    create_before_destroy = true
  }
}


## Security Group for ELB
resource "aws_security_group" "elb" {
  name = "terraform-elb"
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
### Creating ELB
resource "aws_elb" "elb_tf" {
  name = "terraform-asg"
  security_groups = ["sg-093299b047c5d6dfd"]
  availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]
  health_check {
    healthy_threshold = 10
    unhealthy_threshold = 2
    timeout = 5
    interval = 30
    target = "HTTP:8080/index.html"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "8080"
    instance_protocol = "http"
  }
  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "arn:aws:acm:us-east-2:990071541552:certificate/c774216a-5a4d-4678-a841-072ad9c7a11b"
  }
instances                   = ["${aws_instance.elb.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "as_conf-terraform-elb"
  }
}


resource "aws_lb_ssl_negotiation_policy" "elb_tf" {
  name          = "cipher-p"
  load_balancer = "${aws_elb.elb_tf.id}"
  lb_port       = 443

  attribute {
    name  = "Protocol-TLSv1"
    value = "false"
  }

  attribute {
    name  = "Protocol-TLSv1.1"
    value = "false"
  }

  attribute {
    name  = "Protocol-TLSv1.2"
    value = "true"
  }

  attribute {
    name  = "Server-Defined-Cipher-Order"
    value = "true"
  }

  attribute {
    name  = "ECDHE-RSA-AES128-GCM-SHA256"
    value = "true"
  }

  attribute {
    name  = "AES128-GCM-SHA256"
    value = "true"
  }

  attribute {
    name  = "EDH-RSA-DES-CBC3-SHA"
    value = "false"
  }
}
# Create a new load balancer attachment
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = "${aws_autoscaling_group.launch_confg.id}"
  elb                    = "${aws_elb.elb_tf.id}"
}
