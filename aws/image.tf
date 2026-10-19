resource "aws_key_pair" "lustre_lab" {
  key_name   = "lustre-lab"
  public_key = file(var.public_key_path)

  tags = {
    Name = "lustre-lab"
  }
}

resource "aws_iam_role_policy" "cluster_discovery" {
  name = "lustre-lab-cluster-discovery"
  role = aws_iam_role.image_builder_ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ec2:DescribeInstances"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "image_builder_ssm" {
  name = "lustre-lab-image-builder-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "image_builder_ssm" {
  role       = aws_iam_role.image_builder_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "image_builder" {
  name = "lustre-lab-image-builder"
  role = aws_iam_role.image_builder_ssm.name
}


data "aws_ami" "lustre" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Project"
    values = ["lustre-lab"]
  }

  filter {
    name   = "tag:OS"
    values = ["rocky-9"]
  }

  filter {
    name   = "tag:Lustre"
    values = ["2.17.0"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
