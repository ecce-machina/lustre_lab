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
