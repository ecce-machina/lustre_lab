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
