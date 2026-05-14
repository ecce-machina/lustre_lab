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
      image = "projects/rocky-linux-cloud/global/images/family/rocky-linux-9-optimized-gcp"
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

    dnf -y install git

    rm -rf /opt/lustre-helpers
    git clone ${var.repo_url} /opt/lustre-helpers

    cd /opt/lustre-helpers

    bash install_pkgs.sh
    bash build_lustre.sh

    depmod -a

    modprobe lnet || true
    modprobe lustre || true

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
