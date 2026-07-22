provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = "lustre-lab"
      Managed = "terraform"
    }
  }
}

