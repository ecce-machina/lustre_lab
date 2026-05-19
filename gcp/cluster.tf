resource "google_compute_network" "lustre" {
  name                    = "lustre-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "lustre" {
  name          = "lustre-subnet"
  ip_cidr_range = var.cluster_subnet_cidr
  region        = var.region
  network       = google_compute_network.lustre.id
}

resource "google_compute_firewall" "lustre_internal" {
  name    = "lustre-internal"
  network = google_compute_network.lustre.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = [var.cluster_subnet_cidr]
}

resource "google_compute_firewall" "lustre_ssh" {
  name    = "lustre-allow-ssh"
  network = google_compute_network.lustre.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_disk" "mdt0" {
  name = "lustre-mdt0"
  type = "pd-balanced"
  zone = var.zone
  size = var.mdt_disk_size_gb
}

resource "google_compute_disk" "ost" {
  count = var.oss_count
  name  = "lustre-ost${count.index}"
  type  = "pd-balanced"
  zone  = var.zone
  size  = var.ost_disk_size_gb
}

resource "google_compute_instance" "mds" {
  name         = "lustre-mds"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/${var.project_id}/global/images/family/${var.image_family}"
      size  = 80
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.mdt0.id
    device_name = "mdt0"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lustre.id
    network_ip = "10.10.0.10"
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf -y install git || true

    if [[ -d /opt/lustre-helpers ]]; then
      cd /opt/lustre-helpers
      git pull --ff-only
    else
      rm -rf /opt/lustre-helpers
      git clone ${var.repo_url} /opt/lustre-helpers
      cd /opt/lustre-helpers
    fi
    
    bash configure_lustre_role.sh \
      --role mds \
      --fsname ${var.fsname} \
      --mdt-dev /dev/disk/by-id/google-mdt0 \
      --format true
  EOF
  depends_on = [
    google_compute_image.lustre_image
  ]
}

resource "google_compute_instance" "oss" {
  count        = var.oss_count
  name         = "lustre-oss${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/${var.project_id}/global/images/family/${var.image_family}"
      size  = 80
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.ost[count.index].id
    device_name = "ost${count.index}"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lustre.id
    network_ip = "10.10.0.${20 + count.index}"
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf -y install git || true

    if [[ -d /opt/lustre-helpers ]]; then
      cd /opt/lustre-helpers
      git pull --ff-only
    else
      rm -rf /opt/lustre-helpers
      git clone ${var.repo_url} /opt/lustre-helpers
      cd /opt/lustre-helpers
    fi


    bash configure_lustre_role.sh \
      --role oss \
      --fsname ${var.fsname} \
      --mgs-nid 10.10.0.10@tcp \
      --ost-dev /dev/disk/by-id/google-ost${count.index} \
      --index-base ${count.index} \
      --format true
  EOF

  depends_on = [
    google_compute_image.lustre_image,
    google_compute_instance.mds
  ]
}

resource "google_compute_instance" "client" {
  name         = "lustre-client1"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/${var.project_id}/global/images/family/${var.image_family}"
      size  = 80
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lustre.id
    network_ip = "10.10.0.30"
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    dnf -y install git || true

    if [[ -d /opt/lustre-helpers ]]; then
      cd /opt/lustre-helpers
      git pull --ff-only
    else
      rm -rf /opt/lustre-helpers
      git clone ${var.repo_url} /opt/lustre-helpers
      cd /opt/lustre-helpers
    fi
    
    sleep 30

    bash configure_lustre_role.sh \
      --role client \
      --fsname ${var.fsname} \
      --mgs-nid 10.10.0.10@tcp \
      --mountpoint /mnt/lustre
  EOF

  depends_on = [
    google_compute_image.lustre_image,
    google_compute_instance.mds,
    google_compute_instance.oss
  ]
}
