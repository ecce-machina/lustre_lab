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
  default = "lustre-lab-rocky9"
}

variable "machine_type" {
  default = "e2-standard-4"
}

variable "boot_disk_size_gb" {
  default = 100
}

variable "fsname" {
  default = "lustrefs"
}

variable "cluster_subnet_cidr" {
  default = "10.10.0.0/24"
}

variable "mdt_disk_size_gb" {
  default = 100 
}

variable "ost_disk_size_gb" {
  default = 100
}

variable "oss_count" {
  type    = number
  default = 3
}

variable "client_count" {
  type    = number
  default = 2
}


