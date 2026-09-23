### AWS

# Lustre Lab on AWS

This backend deploys a Lustre test cluster on AWS using Terraform.

Before deploying the cluster, a base Lustre image must be built with Packer.

## Build the base image

From the repository root:

```bash
cd packer/aws
packer init .
packer build .
```

## Create cluster

```
cd aws
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform apply
```

## Verify
```
lfs df -h /mnt/lustre

sinfo
srun -N2 -n2 hostname
```

## Destroy

```
terraform destroy
```
