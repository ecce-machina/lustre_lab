packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

variable "region" {
  type    = string
  default = "ca-central-1"
}

variable "instance_type" {
  type    = string
  default = "m6i.xlarge"
}

variable "root_volume_size" {
  type    = number
  default = 100
}

variable "repo_url" {
  type    = string
  default = "https://github.com/ecce-machina/lustre_lab.git"
}

variable "repo_ref" {
  type    = string
  default = "main"
}

variable "ami_name_prefix" {
  type    = string
  default = "lustre-lab-rocky9"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "lustre" {
  region        = var.region
  instance_type = var.instance_type
  ssh_username  = "rocky"

  ami_name        = "${var.ami_name_prefix}-${local.timestamp}"
  ami_description = "Rocky Linux 9 with Lustre server kernel and modules"

  source_ami_filter {
    filters = {
      name                = "Rocky-9-EC2-Base-*.x86_64"
      architecture        = "x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }

    owners      = ["792107900819"]
    most_recent = true
  }

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.ami_name_prefix}-${local.timestamp}"
    Project     = "lustre-lab"
    Purpose     = "lustre-lab"
    OS          = "rocky-9"
    Lustre      = "2.17.0"
    PackerBuild = local.timestamp
  }

  run_tags = {
    Name    = "lustre-lab-packer-builder"
    Project = "lustre-lab"
    Purpose = "image-builder"
  }
}

build {
  name    = "lustre-lab-aws"
  sources = ["source.amazon-ebs.lustre"]

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo -E {{ .Vars }} {{ .Path }}"

    inline = [
      "set -euxo pipefail",
      "dnf install -y https://s3.${var.region}..amazonaws.com/amazon-ssm-ca-central-1/latest/linux_amd64/amazon-ssm-agent.rpm",
      "systemctl enable --now amazon-ssm-agent",
      "systemctl is-enabled amazon-ssm-agent",
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo -E {{ .Vars }} {{ .Path }}"

    environment_vars = [
      "REPO_URL=${var.repo_url}",
      "REPO_REF=${var.repo_ref}",
    ]

    inline = [
      "set -euxo pipefail",
      "dnf -y install git",
      "rm -rf /opt/lustre-helpers",
      "git clone --branch \"$REPO_REF\" --depth 1 \"$REPO_URL\" /opt/lustre-helpers",
      "cd /opt/lustre-helpers",
      "bash install_pkgs.sh",
      "touch /opt/lustre-helpers/.packages_done",
    ]
  }

  provisioner "shell" {
    execute_command   = "chmod +x {{ .Path }}; sudo -E {{ .Vars }} {{ .Path }}"
    expect_disconnect = true

    inline = [
      "sync",
      "systemctl reboot",
    ]
  }

  provisioner "shell" {
    pause_before    = "30s"
    execute_command = "chmod +x {{ .Path }}; sudo -E {{ .Vars }} {{ .Path }}"

    inline = [
      "set -euxo pipefail",
      "cd /opt/lustre-helpers",
      "bash build_lustre.sh --method rpm",
      <<-EOT
        LUSTRE_KERNEL="$(
          rpm -qa --qf '%%{NAME} %%{VERSION}-%%{RELEASE}.%%{ARCH}\n' |
            awk '$1 == "kernel" && $2 ~ /_lustre/ {print $2}' |
            sort -V |
            tail -1
        )"

        if [[ -z "$LUSTRE_KERNEL" ]]; then
          echo "ERROR: could not find installed Lustre kernel"
          rpm -qa | grep '^kernel' | sort
          exit 1
        fi

        echo "$LUSTRE_KERNEL" > /opt/lustre-helpers/.lustre_kernel

        echo "Setting default kernel to $LUSTRE_KERNEL"
        grubby --set-default "/boot/vmlinuz-$LUSTRE_KERNEL"

        touch /opt/lustre-helpers/.build_done
      EOT
    ]
  }

  provisioner "shell" {
    execute_command   = "chmod +x {{ .Path }}; sudo -E {{ .Vars }} {{ .Path }}"
    expect_disconnect = true

    inline = [
      "sync",
      "systemctl reboot",
    ]
  }

  provisioner "shell" {
    pause_before    = "30s"
    execute_command = "chmod +x {{ .Path }}; sudo -E {{ .Vars }} {{ .Path }}"

    inline = [
      "set -euxo pipefail",
      <<-EOT
        LUSTRE_KERNEL="$(cat /opt/lustre-helpers/.lustre_kernel)"

        echo "Expected kernel: $LUSTRE_KERNEL"
        echo "Running kernel:  $(uname -r)"

        test "$(uname -r)" = "$LUSTRE_KERNEL"

        depmod -a

        modprobe lustre
        modprobe ldiskfs
        modprobe osd_ldiskfs

        find "/lib/modules/$(uname -r)" \
          \( \
            -name 'lustre.ko*' -o \
            -name 'lnet.ko*' -o \
            -name 'ldiskfs.ko*' -o \
            -name 'osd_ldiskfs.ko*' \
          \) -print

        lsmod | grep -E 'lustre|lnet|ldiskfs|osd'

        touch /opt/lustre-helpers/.modules_verified
        touch /opt/lustre-helpers/IMAGE_BUILD_DONE
      EOT
    ]
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo -E {{ .Vars }} {{ .Path }}"

    inline = [
      <<-EOT
		  mkdir -p /etc/systemd/system/amazon-ssm-agent.service.d

		  cat >/etc/systemd/system/amazon-ssm-agent.service.d/lustre-lab.conf <<'EOF'
		  [Unit]
		  After=network-online.target cloud-final.service
		  Wants=network-online.target
		  EOF

		  systemctl stop amazon-ssm-agent || true
		  rm -rf /var/lib/amazon/ssm/*
		  rm -f /etc/systemd/system/lustre-lab-ssm-firstboot.service
		  rm -rf /var/lib/lustre-lab

		  systemctl daemon-reload
		  systemctl enable amazon-ssm-agent

		  dnf clean all
		  rm -rf /var/cache/dnf/*
		  sync
		EOT
    ]
  }
}
