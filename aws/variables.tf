variable "region" {}

variable "availability_zone" {}

variable "repo_url" {
  description = "GitHub repo URL for lustre_lab"
}

variable "ami_name" {
  default = "lustre-rocky9-v1"
}

variable "ami_name_prefix" {
  default = "lustre-rocky9"
}

variable "instance_type" {
  default = "m6i.xlarge"
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

variable "oss_count" {
  type    = number
  default = 4
}

variable "client_count" {
  type    = number
  default = 4
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH into the lab, usually your public IP with /32"

  type = string
}

variable "public_key_path" {
  description = "Absolute path to the SSH public key used for EC2"
  type        = string
}

variable "builder_instance_type" {
  description = "EC2 instance type used for the Lustre image builder"
  type        = string
  default     = "m6i.xlarge"
}

