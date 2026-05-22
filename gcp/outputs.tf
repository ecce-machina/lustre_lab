output "builder_name" {
  value = google_compute_instance.image_builder.name
}

output "image_name" {
  value = google_compute_image.lustre_image.name
}

output "image_family" {
  value = google_compute_image.lustre_image.family
}

output "image_self_link" {
  value = google_compute_image.lustre_image.self_link
}

output "mds_private_ip" {
  value = google_compute_instance.mds.network_interface[0].network_ip
}

output "oss_private_ips" {
  value = google_compute_instance.oss[*].network_interface[0].network_ip
}

output "client_private_ips" {
  value = google_compute_instance.client[*].network_interface[0].network_ip
}

output "client_names" {
  value = google_compute_instance.client[*].name
}

output "oss_names" {
  value = google_compute_instance.oss[*].name
}

output "ansible_inventory" {
    value = templatefile("${path.module}/inventory.tmpl", {
        mds_name    = google_compute_instance.mds.name
        mds_ip      = google_compute_instance.mds.network_interface[0].network_ip
        oss_names   = google_compute_instance.oss[*].name
        oss_ips     = google_compute_instance.oss[*].network_interface[0].network_ip
        client_names = google_compute_instance.client[*].name
        client_ips   = google_compute_instance.client[*].network_interface[0].network_ip
        zone        = var.zone
        project_id  = var.project_id
        ansible_user = var.ansible_user
    })
}
