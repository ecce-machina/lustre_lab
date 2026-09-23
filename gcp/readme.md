# Lustre Lab on Google Cloud

This backend deploys a Lustre test cluster on Google Cloud using Terraform.

Before deploying the cluster, a base Lustre image must be built with Packer.

## Build the base image

From the repository root:

```bash
cd packer/gcp
packer init .
packer build .
```

## Create the cluster with tf

```
cd gcp
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform apply
```

## Verify with gcloud ssh or direct ssh to a client

```
lctl df
lctl dl

sinfo
srun -N2 -n2 hostname
```

## Destroy

```
terraform destroy
```
