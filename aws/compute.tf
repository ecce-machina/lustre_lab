
resource "aws_instance" "mgs" {
  ami                    = data.aws_ami.lustre.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.cluster.id
  vpc_security_group_ids = [aws_security_group.cluster.id]

  key_name             = aws_key_pair.lustre_lab.key_name
  iam_instance_profile = aws_iam_instance_profile.image_builder.name

  associate_public_ip_address = true
  user_data                   = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    # Wait for the MDT EBS volume to appear.
    ROOT_DEV="$(findmnt -no SOURCE /)"
    ROOT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_DEV")"

    MDT_DEV=""

    for attempt in {1..30}; do
      MDT_DEV="$(
        lsblk -dnpo NAME,TYPE |
          awk '$2 == "disk" {print $1}' |
          grep -v "^$ROOT_DISK$" |
          head -1
      )"

      if [[ -n "$MDT_DEV" ]]; then
        break
      fi

      echo "Waiting for MDT device..."
      sleep 5
    done

    [[ -n "$MDT_DEV" ]] || {
      echo "ERROR: MDT device not found"
      exit 1
    }

    echo "Using MDT device: $MDT_DEV"

    bash /opt/lustre-lab/configure_lustre_role.sh \
      --role mds \
      --fsname ${var.fsname} \
      --mdt-dev "$MDT_DEV"
EOF
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.boot_disk_size_gb
    volume_type = "gp3"
  }

  tags = {
    Name = "lustre-mgs"
    Role = "mgs"
  }
}

resource "aws_instance" "oss" {
  count = var.oss_count

  ami                    = data.aws_ami.lustre.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.cluster.id
  vpc_security_group_ids = [aws_security_group.cluster.id]

  key_name             = aws_key_pair.lustre_lab.key_name
  iam_instance_profile = aws_iam_instance_profile.image_builder.name

  associate_public_ip_address = true

  root_block_device {
    volume_size = var.boot_disk_size_gb
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    # Wait for the OST EBS volume to appear.
    ROOT_DEV="$(findmnt -no SOURCE /)"
    ROOT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_DEV")"

    OST_DEV=""

    for attempt in {1..30}; do
      OST_DEV="$(
        lsblk -dnpo NAME,TYPE |
          awk '$2 == "disk" {print $1}' |
          grep -v "^$ROOT_DISK$" |
          head -1
      )"

      if [[ -n "$OST_DEV" ]]; then
        break
      fi

      echo "Waiting for OST device..."
      sleep 5
    done

    [[ -n "$OST_DEV" ]] || {
      echo "ERROR: OST device not found"
      exit 1
    }

    echo "Using OST device: $OST_DEV"

    bash /opt/lustre-lab/configure_lustre_role.sh \
      --role oss \
      --fsname ${var.fsname} \
      --mgs-nid ${aws_instance.mgs.private_ip}@tcp \
      --index-base ${count.index} \
      --ost-dev "$OST_DEV"
  EOF

  user_data_replace_on_change = true
  tags = {
    Name = "lustre-oss${count.index + 1}"
    Role = "oss"
  }
}

resource "aws_instance" "client" {
  count = var.client_count

  ami                    = data.aws_ami.lustre.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.cluster.id
  vpc_security_group_ids = [aws_security_group.cluster.id]

  key_name             = aws_key_pair.lustre_lab.key_name
  iam_instance_profile = aws_iam_instance_profile.image_builder.name

  associate_public_ip_address = true
  user_data                   = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    bash /opt/lustre-lab/configure_lustre_role.sh \
      --role client \
      --fsname ${var.fsname} \
      --mgs-nid ${aws_instance.mgs.private_ip}@tcp \
      --mountpoint /mnt/lustre
  EOF

  user_data_replace_on_change = true
  root_block_device {
    volume_size = var.boot_disk_size_gb
    volume_type = "gp3"
  }

  tags = {
    Name = "lustre-client${count.index + 1}"
    Role = "client"
  }
}

