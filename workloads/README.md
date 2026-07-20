# Lustre synthetic workloads

Phase 1 runs one workload on every Slurm client.

Install on the currently running clients from `lustre-client1`:

```bash
cd /opt/lustre-helpers
sudo ./workloads/install.sh
srun -N4 sudo /opt/lustre-helpers/workloads/install.sh
```

The first command installs on the controller. The `srun` command installs on
every allocated client.

Examples:

```bash
lustre-workload list

lustre-workload run prepare-read --size 8G --wait
lustre-workload run read-heavy --duration 300

lustre-workload run write-heavy --size 8G --duration 300

lustre-workload run metadata-create --count 50000 --parallel 16 --wait
lustre-workload run lookup-heavy --duration 300 --parallel 16

lustre-workload status
lustre-workload cancel JOB_ID
```

From another login node:

```bash
ssh lustre-client1 lustre-workload run write-heavy --duration 300
```
