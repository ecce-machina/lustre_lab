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
      size  = 100
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

    cd /opt/lustre-helpers
    bash configure_lustre_role.sh \
      --role mds \
      --fsname ${var.fsname} \
      --mdt-dev /dev/disk/by-id/google-mdt0 \
      --format true
  EOF
}

resource "google_compute_instance" "oss" {
  count        = var.oss_count
  name         = "lustre-oss${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/${var.project_id}/global/images/family/${var.image_family}"
      size  = 100
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

    cd /opt/lustre-helpers

    bash configure_lustre_role.sh \
      --role oss \
      --fsname ${var.fsname} \
      --mgs-nid 10.10.0.10@tcp \
      --ost-dev /dev/disk/by-id/google-ost${count.index} \
      --index-base ${count.index} \
      --format true
  EOF

  depends_on = [
    google_compute_instance.mds
  ]
}

resource "google_compute_instance" "client" {
  count = var.client_count

  name         = "lustre-client${count.index + 1}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/${var.project_id}/global/images/family/${var.image_family}"
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.lustre.id
    network_ip = "10.10.0.${30 + count.index}"
    access_config {}
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    cd /opt/lustre-helpers

    sleep 120

    bash configure_lustre_role.sh \
      --role client \
      --fsname ${var.fsname} \
      --mgs-nid 10.10.0.10@tcp \
      --mountpoint /mnt/lustre

    bash configure_slurm_client.sh \
      --role ${count.index == 0 ? "controller" : "worker"} \
      --node-name lustre-client${count.index + 1} \
      --controller-host lustre-client1 \
      --client-range "lustre-client[1-${var.client_count}]" \
      --cpu-per-client 4 \
      --munge-key '${random_password.munge_key.result}'

	%{if var.enable_monitoring && count.index == 0}
    bash configure_monitoring.sh \
       --mds-ip "10.10.0.10" \
       --oss-ips "${join(",", [for i in range(var.oss_count) : "10.10.0.${20 + i}"])}" \
       --client-ips "${join(",", [for i in range(var.client_count) : "10.10.0.${30 + i}"])}"
	%{endif}

  EOF

  depends_on = [
    google_compute_instance.mds,
    google_compute_instance.oss
  ]
}
