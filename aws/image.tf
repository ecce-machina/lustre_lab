resource "aws_key_pair" "lustre_lab" {
  key_name   = "lustre-lab"
  public_key = file(var.public_key_path)

  tags = {
    Name = "lustre-lab"
  }
}

data "aws_ami" "rocky9" {
  most_recent = true
  owners      = ["792107900819"]

  filter {
    name   = "name"
    values = ["Rocky-9-EC2-Base-*.x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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

resource "aws_instance" "image_builder" {
  ami                         = data.aws_ami.rocky9.id
  instance_type               = var.builder_instance_type
  subnet_id                   = aws_subnet.cluster.id
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  key_name                    = aws_key_pair.lustre_lab.key_name
  private_ip                  = "10.10.0.5"
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.image_builder.name

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y \
      https://s3.ca-central-1.amazonaws.com/amazon-ssm-ca-central-1/latest/linux_amd64/amazon-ssm-agent.rpm

    systemctl enable --now amazon-ssm-agent
  EOF
  
  user_data_replace_on_change = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.boot_disk_size_gb
    delete_on_termination = true
  }

  tags = {
    Name = "lustre-lab-image-builder"
    Role = "image-builder"
  }
}
