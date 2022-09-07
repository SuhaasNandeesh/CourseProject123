terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

#Provider aws
provider "aws" {
  region = "us-east-1"
}

#VPC
resource "aws_vpc" "cp-vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    "Name" = "VPC-${var.name}"
  }
}

#Internet gateway
resource "aws_internet_gateway" "cp-igw" {
  vpc_id = aws_vpc.cp-vpc.id
}

#Creating 2 public subnets in availability zones a and b
resource "aws_subnet" "public" {
  count                   = length(var.subnets_cidr_public)
  cidr_block              = element(var.subnets_cidr_public, count.index)
  vpc_id                  = aws_vpc.cp-vpc.id
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true
  tags = {
    "Name" = "SG-public${var.name}-${count.index + 1}"
  }
}

#Creating 2 private subnets in availability zones a and b
resource "aws_subnet" "private" {
  count             = length(var.subnets_cidr_private)
  cidr_block        = element(var.subnets_cidr_private, count.index)
  vpc_id            = aws_vpc.cp-vpc.id
  availability_zone = element(var.azs, count.index)
  tags = {
    "Name" = "SG-private${var.name}-${count.index + 1}"
  }
}
#Route table
resource "aws_route_table" "cp-route-table" {
  vpc_id = aws_vpc.cp-vpc.id
  route {
    cidr_block = var.route_cidr
    gateway_id = aws_internet_gateway.cp-igw.id
  }
  tags = {
    "Name" = "publicRouteTable"
  }
}

#Route table association for public subnets
resource "aws_route_table_association" "public" {
  count          = length(var.subnets_cidr_public)
  subnet_id      = element((aws_subnet.public)[*].id, count.index)
  route_table_id = aws_route_table.cp-route-table.id
}

resource "aws_nat_gateway" "cp-ngw" {
  depends_on = [
    aws_eip.one
  ]
  connectivity_type = "public"
  count             = 1 //length(var.subnets_cidr_public)
  subnet_id         = element(aws_subnet.public.*.id, count.index)
  //subnet_id         = aws_subnet.public[1].id
  allocation_id = aws_eip.one.id
}

resource "aws_eip" "one" {
  //count                     = length(var.nic_private_ips)
  vpc = true
  # network_interface         = element((aws_network_interface.web-server-nic)[*].id, count.index)
  # associate_with_private_ip = element(var.nic_private_ips, count.index)
  # depends_on = [
  #   aws_internet_gateway.cp-igw
  # ]
}

resource "aws_route_table" "cp-route-table-private" {
  count = 1
  # depends_on = [aws_nat_gateway.cp-ngw]
  vpc_id = aws_vpc.cp-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = element(aws_nat_gateway.cp-ngw.*.id, count.index)
  }

  tags = {
    Name = "privateRouteTable"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  depends_on     = [aws_route_table.cp-route-table-private]
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.cp-route-table-private.*.id, count.index)
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.cp-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Security group and its rule for bastian instance
data "http" "myip" {
  url = "https://checkip.amazonaws.com/"
}
resource "aws_security_group" "bastion" {
  #depends_on  = [aws_subnet.public]
  name        = "ssh-bastion"
  description = "Allow ssh to bastion instance"
  vpc_id      = aws_vpc.cp-vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-host-sg"
  }
}

#Security group and its rule for private instance
resource "aws_security_group" "private" {
  #depends_on  = [aws_subnet.public]
  name        = "private"
  description = "Allow private access to instance"
  vpc_id      = aws_vpc.cp-vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    #cidr_blocks = [aws_vpc.cp-vpc.cidr_block]
    #ipv6_cidr_blocks = [aws_vpc.cp-vpc.ipv6_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-host-sg"
  }
}

#Security group and its rule for public web
resource "aws_security_group" "public" {
  depends_on  = [aws_subnet.public]
  name        = "public-web"
  description = "Allow access at port 80"
  vpc_id      = aws_vpc.cp-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.cp-vpc.cidr_block]
    #ipv6_cidr_blocks = [aws_vpc.cp-vpc.ipv6_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-web-sg"
  }
}

# resource "aws_network_interface" "web-server-nic" {
#   count           = length(var.nic_private_ips)
#   subnet_id       = element((aws_subnet.private)[*].id, count.index)
#   private_ips     = [element(var.nic_private_ips, count.index)]
#   security_groups = [aws_security_group.private.id]
# }




resource "aws_instance" "bastion" {
  ami           = var.ami_type
  instance_type = var.ami_instance_type
  #availability_zone = element(var.azs, 1)
  count                  = 2
  key_name               = var.name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = element(aws_subnet.public.*.id, count.index)
  # network_interface {
  #   device_index         = 0
  #   network_interface_id = aws_network_interface.web-server-nic[1].id
  # }
  tags = {
    "Name" = "bastian"
  }
}

resource "aws_instance" "Jenkins" {
  ami                    = var.ami_type
  instance_type          = var.ami_instance_type
  count                  = 2
  availability_zone      = element(var.azs, count.index)
  key_name               = var.name
  subnet_id              = element(aws_subnet.private.*.id, count.index)
  vpc_security_group_ids = [element(aws_security_group.private.*.id, count.index)]

  # network_interface {
  #   device_index         = 0
  #   network_interface_id = aws_network_interface.web-server-nic[1].id
  # }
  tags = {
    "Name" = "Jenkins"
  }
}

resource "aws_instance" "app" {
  ami                    = var.ami_type
  instance_type          = var.ami_instance_type
  count                  = 2
  availability_zone      = element(var.azs, count.index)
  key_name               = var.name
  subnet_id              = element(aws_subnet.private.*.id, count.index)
  vpc_security_group_ids = [element(aws_security_group.private.*.id, count.index)]
  # network_interface {
  #   device_index         = 0
  #   network_interface_id = aws_network_interface.web-server-nic[1].id
  # }
  tags = {
    "Name" = "app"
  }
}



# resource "aws_subnet" "subnet-2-pub" {
#   cidr_block        = "10.0.2.0/24"
#   vpc_id            = aws_vpc.cp-vpc.id
#   availability_zone = "us-east-1b"
#   tags = {
#     "Name" = "$(var.name)"
#   }
# }

# resource "aws_route_table_association" "b" {
#   subnet_id      = aws_subnet.subnet-2-pub.id
#   route_table_id = aws_route_table.cp-route-table.id
# }

# resource "aws_subnet" "subnet-2-pri" {
#   cidr_block        = "10.0.2.0/24"
#   vpc_id            = aws_vpc.cp-vpc.id
#   availability_zone = "us-east-1b"
#   tags = {
#     "Name" = "$(var.name)"
#   }
# }
# resource "aws_security_group_rule" "example" {
#   type              = "ingress"
#   from_port         = 22
#   to_port           = 22
#   protocol          = "tcp"
#   cidr_blocks       = [aws_vpc.cp-vpc.cidr_block]
#   ipv6_cidr_blocks  = [aws_vpc.cp-vpc.ipv6_cidr_block]
#   security_group_id = aws_security_group.allow_web.id
# }
# data "https" "myip" {
#   url = "https://checkip.amazonaws.com/"
# }
# resource "aws_security_group_rule" "bastian" {
#   type              = "ingress"
#   from_port         = 22
#   to_port           = 22
#   protocol          = "tcp"
#   cidr_blocks       = ["${chomp(data.https.myip.body)}/32"]
#   #ipv6_cidr_blocks  = [aws_vpc.cp-vpc.ipv6_cidr_block]
#   security_group_id = aws_security_group.bastian.id
# }
# data "https" "myip" {
#   url = "https://checkip.amazonaws.com/"
# }
# resource "aws_security_group_rule" "bastian" {
#   type              = "ingress"
#   from_port         = 22
#   to_port           = 22
#   protocol          = "tcp"
#   cidr_blocks       = ["${chomp(data.https.myip.body)}/32"]
#   #ipv6_cidr_blocks  = [aws_vpc.cp-vpc.ipv6_cidr_block]
#   security_group_id = aws_security_group.bastian.id
# }

# resource "aws_vpc_security_group" "allow_vpc" {
#   name        = "allow_vpc_traffic"
#   description = "Allow vpv traffic"
#   vpc_id      = aws_vpc.cp-vpc.id

#   ingress {
#     description = "SSH"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_network_interface" "web-server-nic-2" {
#   subnet_id       = aws_subnet.subnet-2-pri.id
#   private_ips     = ["10.0.2.50"]
#   security_groups = [aws_security_group.allow_web.id]
# }
# resource "aws_eip" "two" {
#   vpc                       = true
#   network_interface         = aws_network_interface.web-server-nic-2.id
#   associate_with_private_ip = "10.0.2.50"
#   depends_on = [
#     aws_internet_gateway.cp-igw
#   ]
# }
