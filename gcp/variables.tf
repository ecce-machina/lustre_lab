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

variable "fsname" {
  default = "lustrefs"
}

variable "cluster_subnet_cidr" {
  default = "10.10.0.0/24"
}

variable "mdt_disk_size_gb" {
  default = 80
}

variable "ost_disk_size_gb" {
  default = 100
}
