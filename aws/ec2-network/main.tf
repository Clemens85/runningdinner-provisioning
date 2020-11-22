provider "aws" {
  region  = var.region
  version = "2.33"
}

terraform {
  backend "s3" {
    bucket = "runyourdinner-terraform-backend"
    key = "services/state.tfstate"
    region = "eu-central-1"
  }
}

// **** Setup Network *** //

// **** Already created **** //
//resource "aws_vpc" "runyourdinner-vpc" {
//  cidr_block = "20.0.0.0/16"
//  tags = {
//    Name = "runyourdinner-network"
//  }
//  enable_dns_hostnames = true
//  enable_dns_support = true
//}

data "aws_vpc" "runyourdinner-vpc" {
  id = "vpc-93b133f8"
}

// Create subnets for CIDR 172.31.48.0/24, 172.31.49.0/24, 172.31.50.0/24 (because we have already some existing subnets
resource "aws_subnet" "runyourdinner-public_subnet" {
  count             = "${length(var.az)}"
//  vpc_id            = "${aws_vpc.runyourdinner-vpc.id}"
  vpc_id = data.aws_vpc.runyourdinner-vpc.id
  availability_zone = "${element(var.az, count.index)}"
  cidr_block        = "172.31.${count.index + 48}.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "runyourdinner-network"
    Service = "runyourdinner"
  }
}

resource "aws_route_table" "runyourdinner-route-table" {
  // vpc_id = "${aws_vpc.runyourdinner-vpc.id}"
  vpc_id = data.aws_vpc.runyourdinner-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
//    gateway_id = "${aws_internet_gateway.runyourdinner-internet-gateway.id}"
    gateway_id = data.aws_internet_gateway.runyourdinner-internet-gateway.id
  }
  tags = {
    Name = "runyourdinner-network"
    Service = "runyourdinner"
  }
}

resource "aws_route_table_association" "runyourdinner-route-table-association" {
  count = 3
  subnet_id      = "${element(aws_subnet.runyourdinner-public_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.runyourdinner-route-table.id}"
}

data "aws_internet_gateway" "runyourdinner-internet-gateway" {
  internet_gateway_id = "igw-b63a4fde"
}
// **** Already created **** //
//resource "aws_internet_gateway" "runyourdinner-internet-gateway" {
//  vpc_id = "${aws_vpc.runyourdinner-vpc.id}"
//  tags = {
//    Name = "runyourdinner-network"
//    Service = "runyourdinner"
//  }
//}


// *** Create Security Group for EC2 which allows HTTP(S) traffic and SSH access for my IP *** //
data "http" "myip" {
  url = "https://api.ipify.org/"
}
resource "aws_security_group" "runyourdinner-public-traffic" {
  name        = "runyourdinner-public-traffic"
  description = "Allow HTTP(S) traffic from public"
//  vpc_id      = "${aws_vpc.runyourdinner-vpc.id}"
  vpc_id      = data.aws_vpc.runyourdinner-vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "runyourdinner-network"
    Service = "runyourdinner"
  }
}
resource "aws_security_group_rule" "runyourdinner-public-traffic-https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.runyourdinner-public-traffic.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "runyourdinner-public-traffic-http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = "${aws_security_group.runyourdinner-public-traffic.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "runyourdinner-public-traffic-ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = "${aws_security_group.runyourdinner-public-traffic.id}"
  cidr_blocks       = ["${chomp(data.http.myip.body)}/32"]
}

// *** Import existing security group from RDS... *** //
data "aws_security_group" "runyourdinner-db-traffic" {
  id = "sg-0cbd96fd17bb2edeb"
}
// ... and add rule to it for allowing security group of EC2 to access database:
resource "aws_security_group_rule" "runyourdinner-db-traffic-sql" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  source_security_group_id = "${aws_security_group.runyourdinner-public-traffic.id}"
  protocol          = "tcp"
  security_group_id = data.aws_security_group.runyourdinner-db-traffic.id
}

// *** Setup EC2 *** //
data "aws_ami" "ubuntu" {
  # most_recent = true
  owners = ["099720109477"]

  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd/ubuntu-xenial-16*-amd64-server*"
    ]
  }
  filter { # Currently I want to stick to a fixed AMI due to I have no AMI based app deployment
    name = "image-id"
    values = [
      "ami-0062c497b55437b01"
    ]
  }
}
resource "aws_key_pair" "runyourdinner-sshkey" {
  key_name = "runyourdinner-sshkey"
  public_key = "${file("../../id_rsa.pub")}"
}
resource "aws_instance" "runyourdinner-appserver" {
  ami = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name = "${aws_key_pair.runyourdinner-sshkey.key_name}"
  tags = {
    Name = "runyourdinner-appserver"
    Service = "runyourdinner"
  }
  associate_public_ip_address = true
  vpc_security_group_ids = ["${aws_security_group.runyourdinner-public-traffic.id}"]
  subnet_id = "${aws_subnet.runyourdinner-public_subnet[0].id}"
//  provisioner "local-exec" {
//    command = "sleep 100; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu -i '${aws_instance.runyourdinner-appserver.public_ip},' ../provision-ec2.yml"
//  }
}
resource "aws_eip" "runyourdinner-eip" {
  instance = "${aws_instance.runyourdinner-appserver.id}"
  vpc      = true
  tags = {
    Name = "runyourdinner-appserver"
    Service = "runyourdinner"
  }
}


data "aws_iam_user" "technical-user" {
  user_name = "technical-user"
}

resource "aws_sqs_queue" "geocode" {
  name = "geocode"
  redrive_policy = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.geocode-dl.arn}\",\"maxReceiveCount\":5}"
  tags = {
    Name = "geocode"
    Service = "runyourdinner"
  }
  policy = <<POLICY
{
   "Version": "2012-10-17",
   "Statement": [{
      "Effect": "Allow",
      "Action": "sqs:*",
      "Resource": "arn:aws:sqs:*:geocode*",
      "Principal": {
        "AWS": [
          "${data.aws_iam_user.technical-user.arn}"
        ]
      }
   }]
}
  POLICY
}

resource "aws_sqs_queue" "geocode-dl" {
  name = "geocode-dl"
  tags = {
    Name = "geocode-dl"
    Service = "runyourdinner"
  }
}

data "aws_iam_group" "dev-group" {
  group_name = "Dev"
}
resource  "aws_iam_policy" "dev-policy" {
  name = "dev-group-policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "s3:*",
        "logs:*",
        "iam:*",
        "apigateway:*",
        "lambda:*",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "events:*",
        "health:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
  POLICY
}
resource "aws_iam_group_policy_attachment" "dev-group-policy" {
  group = data.aws_iam_group.dev-group.group_name
  policy_arn = "${aws_iam_policy.dev-policy.arn}"
}


resource "aws_iam_user" "ci_user" {
  name = "ci_user"
}
resource  "aws_iam_policy" "ci-user-policy" {
  name = "ci-user-policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:RevokeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupIngress"
      ],
      "Resource": [ "*" ]
    },
    {
      "Effect": "Allow",
      "Action": [ "iam:PassRole" ],
      "Resource": [ "*" ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "cloudformation:Describe*",
          "cloudformation:List*",
          "cloudformation:Get*",
          "cloudformation:PreviewStackUpdate",
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:ValidateTemplate"
      ],
      "Resource": [ "*" ]
    },
    {
        "Effect": "Allow",
        "Action": [ "s3:*" ],
        "Resource": [ "*" ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "lambda:GetFunction",
          "lambda:CreateFunction",
          "lambda:DeleteFunction",
          "lambda:UpdateFunctionConfiguration",
          "lambda:UpdateFunctionCode",
          "lambda:ListVersionsByFunction",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:DeleteAlias",
          "lambda:UpdateAlias",
          "lambda:GetFunctionConfiguration",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:InvokeFunction"
      ],
      "Resource": [ "*" ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "apigateway:GET",
          "apigateway:HEAD",
          "apigateway:OPTIONS",
          "apigateway:PATCH",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:DELETE"
      ],
      "Resource": [
          "arn:aws:apigateway:*::/restapis",
          "arn:aws:apigateway:*::/restapis/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "logs:DescribeLogGroups",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DeleteLogGroup",
          "logs:DeleteLogStream",
          "logs:DescribeLogStreams",
          "logs:FilterLogEvents"
      ],
      "Resource": [ "*" ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "events:DescribeRule",
          "events:PutRule",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:DeleteRule"
      ],
      "Resource": [ "*" ]
    }
  ]
}
  POLICY
}

resource "aws_iam_user_policy_attachment" "ci-user-policy_attachmment" {
  user = "${aws_iam_user.ci_user.name}"
  policy_arn = "${aws_iam_policy.ci-user-policy.arn}"
}

// **** Resources that are already created and not managed by terraform **** //

//data "aws_route53_zone" "runyourdinner-dns-zone" {
//  name         = "runyourdinner.eu."
//}
//resource "aws_route53_record" "sendgrid" {
//  zone_id = data.aws_route53_zone.runyourdinner-dns-zone.zone_id
//  name    = "mail.runyourdinner.eu."
//  type    = "CNAME"
//  ttl     = "300"
//  records = ["u3158000.wl001.sendgrid.net"]
//}
//resource "aws_route53_record" "sendgrid-s1" {
//  zone_id = data.aws_route53_zone.runyourdinner-dns-zone.zone_id
//  name    = "s1._domainkey.runyourdinner.eu."
//  type    = "CNAME"
//  ttl     = "300"
//  records = ["s1.domainkey.u3158000.wl001.sendgrid.net"]
//}
//resource "aws_route53_record" "sendgrid-s2" {
//  zone_id = data.aws_route53_zone.runyourdinner-dns-zone.zone_id
//  name    = "s2._domainkey.runyourdinner.eu."
//  type    = "CNAME"
//  ttl     = "300"
//  records = ["s2.domainkey.u3158000.wl001.sendgrid.net"]
//}
//resource "aws_route53_record" "google" {
//  zone_id = data.aws_route53_zone.runyourdinner-dns-zone.zone_id
//  name    = "runyourdinner.eu."
//  type    = "TXT"
//  ttl     = "300"
//  records = ["google-site-verification=mkZzpyYlrX3vVbFf70RZyxkKMvVDpf8WowRfapqjPtg"]
//}
//resource "aws_route53_record" "SOA" {
//  zone_id = data.aws_route53_zone.runyourdinner-dns-zone.zone_id
//  name    = "runyourdinner.eu."
//  type    = "SOA"
//  ttl     = "900"
//  records = ["ns-1269.awsdns-30.org. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"]
//}
//resource "aws_route53_record" "alias-eip-appserver" {
//  zone_id = data.aws_route53_zone.runyourdinner-dns-zone.zone_id
//  name    = "runyourdinner.eu."
//  type    = "A"
//  records = ["${aws_eip.runyourdinner-eip.public_ip}"]
//  ttl = "600"
//}



//Already created VPC with already existing subnets and new subnets to be created:
//
//ALLES
//CIDR Range	172.31.0.0/16
//First IP	172.31.0.0
//Last IP	    172.31.255.255
//
//SUBNET 1
//CIDR Range	172.31.0.0/20
//First IP	172.31.0.0
//Last IP	    172.31.15.255
//
//SUBNET 2
//CIDR Range	172.31.16.0/20
//First IP	172.31.16.0
//Last IP	    172.31.31.255
//
//SUBNET 3
//CIDR Range	172.31.32.0/20
//First IP	172.31.32.0
//Last IP	    172.31.47.255
//
//NEU:
//SUBNET 1a
//CIDR Range	172.31.48.0/24
//First IP	172.31.48.0
//Last IP	    172.31.48.255
//
//SUBNET 1b
//CIDR Range	172.31.49.0/24
//First IP	172.31.49.0
//Last IP	    172.31.49.255
//
//SUBNET 1c
//CIDR Range	172.31.50.0/24
//First IP	172.31.50.0
//Last IP	    172.31.50.255






# https://blog.gruntwork.io/an-introduction-to-terraform-f17df9c6d180
# https://blog.gruntwork.io/terraform-up-running-2nd-edition-early-release-is-now-available-b104fc29783f
# https://hackernoon.com/introduction-to-aws-with-terraform-7a8daf261dc0
# https://github.com/terraform-aws-modules/terraform-aws-vpc
#  https://www.webcodegeeks.com/devops/terraforming-docker-environment-aws/
#  https://blog.codeship.com/shared-resources-for-your-terraformed-docker-environment-on-aws/

