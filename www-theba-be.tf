
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "key_path" {}
variable "key_name" {}
variable "aws_region" {
    default = "us-east-1"
}

# Amazon Linux AMIs
variable "aws_amis" {
    default = {
        "us-east-1": "ami-76817c1e",
        "us-west-1": "ami-f0d3d4b5",
        "us-west-2": "ami-d13845e1"
    }
}

# Specify the provider and access details
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "${var.aws_region}"
}

# Our default security group to access
# the instances over SSH, HTTP, and HTTPS
resource "aws_security_group" "default" {
    name = "ssh_http_https2"
    description = "Allow SSH, HTTP, HTTPS"

    # SSH access from anywhere
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # HTTP access from anywhere
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    
    # HTTPs access from anywhere
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_route53_zone" "primary" {
   name = "theba.be"
}

resource "aws_route53_record" "www" {
   zone_id = "${aws_route53_zone.primary.zone_id}"
   name = "www.theba.be"
   type = "CNAME"
   ttl = "300"
   records = ["${aws_elb.web.dns_name}"]
}

resource "aws_elb" "web" {
  name = "www-theba-be-elb"

  # The same availability zone as our instance
  availability_zones = ["${aws_instance.web.availability_zone}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  listener {
    instance_port = 443
    instance_protocol = "https"
    lb_port = 443
    lb_protocol = "https"
  }

  # The instance is registered automatically
  instances = ["${aws_instance.web.id}"]
}


resource "aws_instance" "web" {
  description "The Bab.be Webserver"
  
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ec2-user"

    # The path to your keyfile
    key_file = "${var.key_path}"
  }

  instance_type = "m3.medium"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"

  # The name of our SSH keypair you've created and downloaded
  # from the AWS console.
  #
  # https://console.aws.amazon.com/ec2/v2/home?region=us-west-2#KeyPairs:
  #
  key_name = "${var.key_name}"

  # Our Security group to allow HTTP and SSH access
  security_groups = ["${aws_security_group.default.name}"]

  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
  provisioner "remote-exec" {
    inline = [
        "sudo yum upgrade -y",
        "sudo yum install httpd -y"
        "sudo service httpd start"
    ]
  }
}

output "address" {
  value = "${aws_elb.web.dns_name}"
}