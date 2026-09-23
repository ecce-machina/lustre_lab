# lustre_lab

`lustre_lab` is a project for building disposable Lustre test clusters for learning, development, troubleshooting, and reproducer work.

The lab can currently be deployed using three backends:

| Backend | Use case |
| --- | --- |
| **QEMU/KVM** | Local development and testing using libvirt/QEMU VMs |
| **Google Cloud (GCP)** | Cloud-based Lustre test clusters on Google Compute Engine |
| **Amazon Web Services (AWS)** | Cloud-based Lustre test clusters on Amazon EC2 |

Each backend has its own configuration and deployment instructions.

## QEMU/KVM

The QEMU backend uses Packer to build a reusable VM image and libvirt/KVM to create disposable Lustre clusters locally.

It supports configurable numbers of OSS and client nodes, automated Lustre configuration, and Slurm across the client nodes.

See [`qemu/README.md`](qemu/README.md).

## Google Cloud

The GCP backend uses Terraform to provision the Lustre infrastructure in Google Cloud.

See [`gcp/README.md`](gcp/README.md).

## AWS

The AWS backend uses Terraform to provision the Lustre infrastructure in AWS.

See [`aws/README.md`](aws/README.md).

## Common layout

Regardless of backend, the goal is to provide a small, reproducible Lustre environment consisting of:

- MGS/MDT
- One or more OSS/OSTs
- One or more Lustre clients
- Slurm-capable client nodes where supported

The environments are intended to be disposable: create a cluster, reproduce or investigate a behavior, collect results, and tear the cluster down.

Backend-specific prerequisites, configuration, deployment, and cleanup instructions are documented in the corresponding README.