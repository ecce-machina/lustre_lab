packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "build_method" {
  type    = string
  default = "source"
}

variable "lustre_ref" {
  type    = string
  default = "2.17.59"
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

  output_directory = "${path.root}/output"
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

  http_directory = "${path.root}/http"

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
      "rm -rf /opt/lustre-lab",
      "git clone --branch \"$REPO_REF\" --depth 1 \"$REPO_URL\" /opt/lustre-lab",
      "cd /opt/lustre-lab",
      "bash install_pkgs.sh",
     # "bash workloads/install.sh",
     # "sudo dnf install -y epel-release",
     # "sudo dnf install -y munge munge-libs slurm slurm-slurmd slurm-slurmctld fio",
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
      "cd /opt/lustre-lab",
      "KVER=$(uname -r)",
      "test -d /usr/src/kernels/$KVER || { echo \"ERROR: kernel-devel missing for $KVER\"; exit 1; }",
      "bash build_lustre.sh --method ${var.build_method} --lustre-ref ${var.lustre_ref}",
      "echo 'Running kernel:'; uname -r",
      "echo 'Installed kernel images:'; ls -l /boot/vmlinuz-*",
      "echo 'Installed kernel packages:'; rpm -qa 'kernel*' | sort",
      <<-EOT
        if [[ "${var.build_method}" == "source" ]]; then
          echo "Selecting kernel for source-built Lustre modules"

          LUSTRE_KERNEL="$(
            find /lib/modules -type f -path '*/extra/lustre/fs/lustre.ko' |
              sed -n 's#^/lib/modules/\([^/]*\)/extra/lustre/fs/lustre\.ko$#\1#p' |
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
          echo "ERROR: could not determine Lustre kernel"
          exit 1
        fi

        echo "Selected Lustre kernel: $LUSTRE_KERNEL"
        echo "$LUSTRE_KERNEL" > /opt/lustre-lab/.lustre_kernel

        if [[ ! -f "/boot/vmlinuz-$LUSTRE_KERNEL" ]]; then
          echo "ERROR: kernel image missing: $LUSTRE_KERNEL"
          exit 1
        fi
        grubby --set-default "/boot/vmlinuz-$LUSTRE_KERNEL"
        if [[ ! -f "/boot/vmlinuz-$LUSTRE_KERNEL" ]]; then
            echo "ERROR: Lustre modules were installed for $LUSTRE_KERNEL"
            echo "but the corresponding kernel image is missing."
            echo "Installed kernels:"
            ls -l /boot/vmlinuz-*
            exit 1
        fi
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

        LUSTRE_KERNEL="$(cat /opt/lustre-lab/.lustre_kernel)"

        test "$(uname -r)" = "$LUSTRE_KERNEL"

        depmod -a "$LUSTRE_KERNEL"

        modprobe lustre
        modprobe ldiskfs
        modprobe osd_ldiskfs

        touch /opt/lustre-lab/IMAGE_BUILD_DONE
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
      "touch /opt/lustre-lab/.ssh_key_installed",
     
      "printf '%s\n' '[Unit]' 'Description=Load Lustre kernel modules' 'After=network-online.target' 'Wants=network-online.target' '' '[Service]' 'Type=oneshot' 'ExecStart=/usr/sbin/modprobe lustre' 'ExecStart=/usr/sbin/modprobe ldiskfs' 'ExecStart=/usr/sbin/modprobe osd_ldiskfs' 'RemainAfterExit=yes' '' '[Install]' 'WantedBy=multi-user.target' > /etc/systemd/system/lustre-modules.service", 
      "systemctl daemon-reload",
      "systemctl enable lustre-modules.service",
      "sync",
    ]
  }
}   
 

