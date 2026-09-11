packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "ssh_public_key_file" {
  type = string
}

variable "qemu_binary" {
  type    = string
  default = "qemu-system-x86_64"
}

variable "repo_url" {
  type    = string
  default = "https://github.com/ecce-machina/lustre_lab.git"
}

variable "repo_ref" {
  type    = string
  default = "main"
}

source "qemu" "lustre" {
  iso_url      = "https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9-latest-x86_64-minimal.iso"
  iso_checksum = "none"

  output_directory = "output"
  vm_name          = "lustre-lab-rocky9.qcow2"

  format    = "qcow2"
  disk_size = "40G"

  memory = 4096
  cpus   = 4

  headless     = true
  accelerator  = "kvm"

  qemuargs = [
    ["-cpu", "host"]
  ]
  qemu_binary  = var.qemu_binary

  ssh_username = "packer"
  ssh_password = "packer"
  ssh_timeout  = "30m"

  http_directory = "http"

  boot_wait = "10s"

  boot_command = [
    "<tab><wait>",
    " inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
    "<enter>"
  ]
  net_device     = "virtio-net"
  disk_interface = "virtio"
}


build {
  name    = "lustre-lab-qemu"
  sources = ["source.qemu.lustre"]

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

        test -n "$LUSTRE_KERNEL"

        echo "$LUSTRE_KERNEL" > /opt/lustre-helpers/.lustre_kernel

        grubby --set-default "/boot/vmlinuz-$LUSTRE_KERNEL"
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
      <<-EOT
        set -euxo pipefail

        LUSTRE_KERNEL="$(cat /opt/lustre-helpers/.lustre_kernel)"

        test "$(uname -r)" = "$LUSTRE_KERNEL"

        depmod -a "$LUSTRE_KERNEL"

        cat >/etc/modules-load.d/lustre.conf <<'EOF'
        lustre
        ldiskfs
        osd_ldiskfs
        EOF
        
        modinfo lustre
        modprobe lustre
        modprobe ldiskfs
        modprobe osd_ldiskfs

        touch /opt/lustre-helpers/IMAGE_BUILD_DONE
      EOT
    ]
  }
  

  provisioner "file" {
    source      = var.ssh_public_key_file
    destination = "/tmp/lustre_lab.pub"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; sudo -E {{ .Vars }} {{ .Path }}"

    inline = [
      "set -euxo pipefail",
      "install -d -m 700 -o packer -g packer /home/packer/.ssh",
      "install -m 600 -o packer -g packer /tmp/lustre_lab.pub /home/packer/.ssh/authorized_keys",
      "test -s /home/packer/.ssh/authorized_keys",
      "grep -q '^ssh-' /home/packer/.ssh/authorized_keys",
      "touch /opt/lustre-helpers/.ssh_key_installed",
    ]
  }
}   
 

