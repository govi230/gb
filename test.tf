provider "aws" {
  region    = "ap-south-1"
  profile   = "myhybridcloud"
}

variable "enter_key_name" {
  type = string
  default = "helo"
}
variable "enter_security_group_name" {
  type = string
  default = "securityhttpssh"
}
variable "enter_ami_id" {
  type = string
  default = "ami-018886bdc77212e1d"
}
variable "enter_instance_type" {
  type = string
  default = "t2.micro"
}
variable "enter_availability_zone" {
  type = string
  default = "ap-south-1b"
}
variable "root_block_volume_type" {
  type = string
  default = "gp2"
}
variable "root_block_volume_size" {
  type = string
  default = 8
}
variable "delete_on_termination_of_root_block_volume" {
  type = bool
  default = true
}
variable "enter_ebs_volume_type" {
  type = string
  default = "gp2"
}
variable "enter_ebs_volume_size" {
  type = number
  default = 1
}
variable "enter_ebs_volume_device_name" {
  type = string
  default = "/dev/sdf"
}

resource "aws_security_group" "securitytest" {
  name = var.enter_security_group_name
  ingress {
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
  from_port = 22
  to_port = 22
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "instance1" {
  ami = var.enter_ami_id
  instance_type = var.enter_instance_type
  availability_zone = var.enter_availability_zone
  root_block_device {
  volume_type = var.root_block_volume_type
  volume_size = var.root_block_volume_size
  delete_on_termination = var.delete_on_termination_of_root_block_volume
  }
  security_groups = [var.enter_security_group_name]
  key_name = var.enter_key_name
  volume_tags = {
  Nmae = "root_first_volume"
  }
  tags = {
  Name = "first_task_inatance"
  }
  depends_on = [
  aws_security_group.securitytest
  ]
}
resource "null_resource" "command" {
    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = file("C:/Users/DELL/Downloads/helo.pem")
      host = aws_instance.instance1.public_ip
    }
    provisioner "remote-exec" {
      inline = [
        "sudo yum install httpd git php -y",
        "sudo systemctl restart httpd",
        "sudo systemctl enable httpd",
        "sudo mkfs.ext4 /dev/xvdf",
        "sudo mount /dev/xvdf /var/www/html/",
        "sudo rm -rf /var/www/html/*",
        "sudo git clone https://github.com/govi230/gb.git /var/www/html/",
      ]
    }
   depends_on = [
   aws_volume_attachment.attach-ebs
   ]
}

resource "aws_ebs_volume" "vol" {
  availability_zone = var.enter_availability_zone
  size = var.enter_ebs_volume_size
  type = var.enter_ebs_volume_type
  tags = {
  Name = "taskvol1"
  }
  depends_on = [
   aws_instance.instance1
  ]
}

resource "aws_volume_attachment" "attach-ebs" {
  device_name = var.enter_ebs_volume_device_name
  volume_id = aws_ebs_volume.vol.id
  instance_id = aws_instance.instance1.id
  force_detach = true
  depends_on = [
  aws_ebs_volume.vol
  ]
}

resource "aws_s3_bucket" "govibucket" {
  bucket = "govi230bucket"
  acl = "public-read"
  tags = {
  Name = "firstbucket"
  }
  depends_on = [
  null_resource.command
  ]
}

resource "aws_s3_bucket_object" "s3_object" {
  key                    = "lightblue.jpg"
  bucket                 = aws_s3_bucket.govibucket.id
  source                 = "D:/LogIN.jpg"
  acl = "public-read"
  depends_on = [
  aws_s3_bucket.govibucket
  ]
}
locals {
  s3_origin_id = "myS3Origin"
}


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.govibucket.bucket_regional_domain_name
    origin_id = local.s3_origin_id
  }
  enabled = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  restrictions{
    geo_restriction{
      restriction_type = "none"
    }
  }
    default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
  target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }
  price_class = "PriceClass_200"
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  depends_on = [
  aws_s3_bucket_object.s3_object
  ]
}
output "cloudfront" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
output "instance_ip" {
  value = aws_instance.instance1.public_ip
}