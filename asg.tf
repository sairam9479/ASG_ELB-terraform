


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
    target = "HTTP:80/index.html"
  }
  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }
}

# Create a new load balancer attachment
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = "${aws_autoscaling_group.launch_confg.id}"
  elb                    = "${aws_elb.elb_tf.id}"
}


####r53
resource "aws_route53_zone" "terraform-sairam" {
  name   = "sairam.cf"
}
resource "aws_route53_record" "terraform-asg-example-lb-tf" {
  zone_id = "${aws_route53_zone.terraform-sairam.zone_id}"
  name    = "sairam.cf"
  type    = "A"

  alias {
    name                   = "${aws_elb.elb_tf.dns_name}"
    zone_id                = "${aws_elb.elb_tf.zone_id}"
    evaluate_target_health = true
  }
}
