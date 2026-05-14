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
      echo "=== PHASE 2: building Lustre ==="
      bash build_lustre.sh --method rpm
      depmod -a || true

      echo "=== Built modules found ==="
      find /lib/modules/$(uname -r) \
        \( -name 'lustre.ko*' -o -name 'lnet.ko*' -o -name 'ldiskfs.ko*' \) \
        -print || true

      touch /opt/lustre-helpers/.build_done
    fi

    echo "=== IMAGE_BUILD_DONE ==="
    touch /opt/lustre-helpers/IMAGE_BUILD_DONE
  EOF

  allow_stopping_for_update = true
}

resource "google_compute_image" "lustre_image" {
  name        = var.image_name
  family      = var.image_family
  source_disk = google_compute_instance.image_builder.boot_disk[0].source

  depends_on = [google_compute_instance.image_builder]
}
