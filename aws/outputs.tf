output "vpc_id" {
  description = "ID of the Lustre lab VPC"
  value       = aws_vpc.lustre_lab.id
}

output "cluster_subnet_id" {
  description = "ID of the cluster subnet"
  value       = aws_subnet.cluster.id
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = aws_security_group.cluster.id
}

output "rocky9_ami_id" {
  description = "Rocky Linux 9 base AMI selected for the builder"
  value       = data.aws_ami.rocky9.id
}

output "image_builder_instance_id" {
  description = "EC2 instance ID of the Lustre image builder"
  value       = aws_instance.image_builder.id
}

output "image_builder_public_ip" {
  description = "Public IP address of the Lustre image builder"
  value       = aws_instance.image_builder.public_ip
}

output "image_builder_private_ip" {
  description = "Private IP address of the Lustre image builder"
  value       = aws_instance.image_builder.private_ip
}

