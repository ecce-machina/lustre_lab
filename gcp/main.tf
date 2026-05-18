provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_instance" "image_builder" {
  name         = "lustre-image-builder"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/rocky-linux-cloud/global/images/family/rocky-linux-9"
      size  = var.boot_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"

    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    LOG=/var/log/lustre-image-build.log
    exec > >(tee -a "$LOG") 2>&1

    dnf -y install git

    if [[ ! -d /opt/lustre-helpers ]]; then
      git clone ${var.repo_url} /opt/lustre-helpers
    fi

    cd /opt/lustre-helpers

    if [[ ! -f /opt/lustre-helpers/.packages_done ]]; then
      echo "=== PHASE 1: installing packages ==="
      bash install_pkgs.sh
      touch /opt/lustre-helpers/.packages_done
      echo "=== PHASE 1 complete; rebooting ==="
      reboot
      exit 0
    fi

    if [[ ! -f /opt/lustre-helpers/.build_done ]]; then
      echo "=== PHASE 2: installing Lustre RPMs ==="
      bash build_lustre.sh --method rpm

      LUSTRE_KERNEL="$(rpm -qa --qf '%%{NAME} %%{VERSION}-%%{RELEASE}.%%{ARCH}\n' \
          | awk '$1 == "kernel" && $2 ~ /_lustre/ {print $2}' \
          | sort -V \
          | tail -1)"

      if [[ -z "$LUSTRE_KERNEL" ]]; then
          echo "ERROR: could not find installed Lustre kernel"
          rpm -qa | grep '^kernel' | sort
          exit 1
      fi
      
      echo "=== Setting default kernel to $LUSTRE_KERNEL ==="
      grubby --set-default "/boot/vmlinuz-$LUSTRE_KERNEL"

      touch /opt/lustre-helpers/.build_done

      echo "=== PHASE 2 complete; rebooting into Lustre kernel ==="
      reboot
      exit 0
    fi

    if [[ ! -f /opt/lustre-helpers/.modules_verified ]]; then
      echo "=== PHASE 3: verifying Lustre modules ==="

      LUSTRE_KERNEL="$(cat /opt/lustre-helpers/.lustre_kernel)"

      echo "Expected Lustre kernel: $LUSTRE_KERNEL"
      echo "Running kernel: $(uname -r)"

      [[ "$(uname -r)" == "$LUSTRE_KERNEL" ]]

      depmod -a

      modprobe lustre
      modprobe ldiskfs
      modprobe osd_ldiskfs

      find /lib/modules/$(uname -r) \
          \( -name 'lustre.ko*' -o -name 'lnet.ko*' -o -name 'ldiskfs.ko*' -o -name 'osd_ldiskfs.ko*' \) \
          -print

      lsmod | grep -E 'lustre|lnet|ldiskfs|osd'

      touch /opt/lustre-helpers/.modules_verified
   fi

        echo "=== IMAGE_BUILD_DONE ==="
        touch /opt/lustre-helpers/IMAGE_BUILD_DONE
        shutdown -h now
  EOF

  allow_stopping_for_update = true
}

resource "google_compute_image" "lustre_image" {
  name        = var.image_name
  family      = var.image_family
  source_disk = google_compute_instance.image_builder.boot_disk[0].source

  depends_on = [google_compute_instance.image_builder]
}
