## Spin up a small lab cluster on GCP

First, configure the settings for the cluster you want to build in variables.tf

Then, we need to build the lustre image so it can be used for the client/MDS/OSS nodes

```
cd lustre_helpers/gcp
terraform apply -target=google_compute_instance.image_builder
```

Check the progress:

```
cloud compute ssh lustre-image-builder \
  --zone <your zone> \
  --command='sudo tail -f /var/log/lustre-image-build.log'
```

It basically installs all the rpms required and the e2fs-progs with the wc patch along with all the lustre rpms(You can also build from source if needed)

Once it's completed, you stop the image builder:

```
gcloud compute instances stop lustre-image-builder \
  --zone us-central1-a
```

And you can run apply for the rest. According to your variables, it'll create clients, mds and oss.

```
terraform apply
```

You can test slrum on lustre-client1:

```
$ gcloud compute ssh lustre-client1 \
  --zone <your zone> \
  --command='sinfo'
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite      4   idle lustre-client[1-4]

$ gcloud compute ssh lustre-client1 \
  --zone <your zone> \
  --command='srun -N4 hostname'
lustre-client2
lustre-client1
lustre-client3
lustre-client4
```
