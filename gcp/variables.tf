variable "project_id" {}
variable "region" {}
variable "zone" {}

variable "repo_url" {
  description = "GitHub repo URL for lustre-helpers"
}

variable "image_name" {
  default = "lustre-rocky9-v1"
}

variable "image_family" {
  default = "lustre-rocky9"
}

variable "machine_type" {
  default = "e2-standard-4"
}

variable "boot_disk_size_gb" {
  default = 80
}
