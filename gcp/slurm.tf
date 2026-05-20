resource "random_password" "munge_key" {
  length  = 64
  special = false
}
