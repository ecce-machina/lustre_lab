resource "aws_vpc" "lustre_lab" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "lustre-lab"
  }
}

resource "aws_subnet" "cluster" {
  vpc_id                  = aws_vpc.lustre_lab.id
  cidr_block              = var.cluster_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "lustre-lab-cluster"
  }
}

resource "aws_internet_gateway" "lustre_lab" {
  vpc_id = aws_vpc.lustre_lab.id

  tags = {
    Name = "lustre-lab"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lustre_lab.id

  tags = {
    Name = "lustre-lab-public"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lustre_lab.id
}

resource "aws_route_table_association" "cluster" {
  subnet_id      = aws_subnet.cluster.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "cluster" {
  name        = "lustre-lab-cluster"
  description = "Lustre lab cluster traffic"
  vpc_id      = aws_vpc.lustre_lab.id

  tags = {
    Name = "lustre-lab-cluster"
  }
}

resource "aws_vpc_security_group_ingress_rule" "cluster_internal" {
  security_group_id = aws_security_group.cluster.id
  description       = "Allow all traffic within the cluster subnet"

  cidr_ipv4   = var.cluster_subnet_cidr
  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.cluster.id
  description       = "Allow SSH from administrator address"

  cidr_ipv4   = var.admin_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "icmp" {
  security_group_id = aws_security_group.cluster.id
  description       = "Allow ICMP from administrator address"

  cidr_ipv4   = var.admin_cidr
  from_port   = -1
  to_port     = -1
  ip_protocol = "icmp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.cluster.id
  description       = "Allow outbound traffic"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
