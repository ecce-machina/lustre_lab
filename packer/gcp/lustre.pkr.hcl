packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
  }
}

variable "project_id" {
  type = string
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "machine_type" {
  type    = string
  default = "n2-standard-4"
}

variable "disk_size" {
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

variable "image_family" {
  type    = string
  default = "lustre-lab-rocky9"
}

variable "image_name_prefix" {
  type    = string
  default = "lustre-lab-rocky9"
}

variable "build_method" {
  type    = string
  default = "rpm"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "googlecompute" "lustre" {
  project_id   = var.project_id
  zone         = var.zone
  machine_type = var.machine_type

  ssh_username = "rocky"

  source_image_family     = "rocky-linux-9"
  source_image_project_id = ["rocky-linux-cloud"]

  image_name        = "${var.image_name_prefix}-${local.timestamp}"
  image_description = "Rocky Linux 9 with Lustre server kernel and modules"
  image_family 		= var.image_family

  metadata = {
    enable-oslogin = "FALSE"
  }
  disk_size = var.disk_size

  image_labels = {
    project = "lustre-lab"
    purpose = "lustre-lab"
    os      = "rocky-9"
    lustre  = "2-17-0"
  }
}

build {
  name    = "lustre-lab-gcp"
  sources = ["source.googlecompute.lustre"]

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
      "bash build_lustre.sh --method ${var.build_method}",
      <<-EOT
      if [[ "${var.build_method}" == "source" ]]; then
          echo "Selecting kernel for source-built Lustre modules"

          LUSTRE_KERNEL="$(
            find /lib/modules -type f -path '*/extra/lustre/fs/lustre.ko' -printf '%h\n' |
              sed 's#/extra/lustre/fs##' |
              xargs -r basename |
              sort -V |
              tail -1
          )"
        else
          echo "Selecting Whamcloud Lustre kernel"

          LUSTRE_KERNEL="$(
            rpm -qa --qf '%%{NAME} %%{VERSION}-%%{RELEASE}.%%{ARCH}\n' |
              awk '$1 == "kernel" && $2 ~ /_lustre/ {print $2}' |
              sort -V |
              tail -1
          )"
        fi

        if [[ -z "$LUSTRE_KERNEL" ]]; then
          echo "ERROR: could not determine Lustre kernel for build method ${var.build_method}"
          rpm -qa | grep '^kernel' | sort || true
          find /lib/modules -name 'lustre.ko*' -print || true
          exit 1
        fi

        echo "Selected Lustre kernel: $LUSTRE_KERNEL"
        echo "$LUSTRE_KERNEL" > /opt/lustre-helpers/.lustre_kernel

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
      "dnf clean all",
      "rm -rf /var/cache/dnf/*",
      "sync",
    ]
  }
}

