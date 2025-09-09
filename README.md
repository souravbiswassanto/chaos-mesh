# Chaos Engineering for KubeDB PostgreSQL

This repository contains a comprehensive set of [Chaos Mesh](https://chaos-mesh.org/) experiments designed to test the resilience and high-availability of a [KubeDB](https://kubedb.com/)-managed PostgreSQL cluster on Kubernetes.

The experiments are structured to increase in complexity, from single fault injections to complex, scheduled workflows.

## Directory Structure

* `/setup`: Contains manifests for deploying the target HA PostgreSQL cluster and a client pod.
* `/1-single-experiments`: Contains individual, one-off chaos experiments for various failure types.
* `/2-scheduled-experiments`: Contains chaos experiments that run on a recurring schedule.
* `/3-workflows`: Contains multi-step chaos workflows that simulate complex outage scenarios.

## Prerequisites

1.  A running Kubernetes cluster.
2.  `kubectl` configured to connect to your cluster.
3.  [KubeDB Operator](https://kubedb.com/docs/latest/setup/) installed.
4.  [Chaos Mesh](https://chaos-mesh.org/docs/quick-start/) installed.

## Getting Started

### 1. Run the Setup Script

To create the entire directory structure and all experiment files, run the provided script:

```bash
chmod +x create-chaos-structure.sh
./create-chaos-structure.sh
```

### 2. Deploy the Target PostgreSQL Cluster

First, create the namespace and deploy the highly-available PostgreSQL cluster and the client pod for testing.

```bash
# Deploy the 3-node PostgreSQL cluster and client pod
kubectl apply -f setup/kubedb-postgres.yaml
kubectl apply -f setup/client-pod.yaml

# Add a label to the client pod for DNSChaos targeting
kubectl label pod client-pod -n demo pod-name=client-pod
```

Wait for all pods to be in a `Running` state:

```bash
kubectl get pods -n demo -w
```

You can identify the primary and replica pods using their labels:

```bash
# Find the primary
kubectl get pods -n demo -l app.kubernetes.io/instance=pg-ha-cluster,[kubedb.com/role=primary](https://kubedb.com/role=primary)

# Find the replicas
kubectl get pods -n demo -l app.kubernetes.io/instance=pg-ha-cluster,[kubedb.com/role=standby](https://kubedb.com/role=standby)
```

### 3. Running the Experiments

Apply the YAML file for the experiment you want to run. Below is a summary of the available experiments.

#### Single Experiments (`1-single-experiments/`)

* **`pod-kill-primary.yaml`**: Kills the primary pod to test automatic failover.
* **`network-latency-primary-to-replicas.yaml`**: Adds 150ms latency between the primary and replicas to test replication lag.
* **`network-partition-primary.yaml`**: Isolates the primary from replicas to test split-brain prevention.
* **`io-latency-primary.yaml`**: Simulates a slow disk on the primary pod.
* **`stress-cpu-primary.yaml`**: Injects high CPU load on the primary.
* **`stress-memory-replica.yaml`**: Injects high memory load on a replica to test OOMKilled recovery.
* **`dns-error-from-client.yaml`**: Simulates DNS resolution failures from the client pod to the database service.

#### Scheduled Experiments (`2-scheduled-experiments/`)

* **`schedule-nightly-replica-kill.yaml`**: Kills a random replica pod every night at 1 AM.
* **`schedule-weekend-cpu-stress.yaml`**: Runs a 30-minute CPU stress test on the primary every Saturday and Sunday at 4 AM.

#### Workflow Experiments (`3-workflows/`)

* **`workflow-degraded-failover.yaml`**: Makes the primary's storage slow and *then* kills the pod to test failover under duress.
* **`workflow-flaky-network-failover.yaml`**: Creates packet loss to one replica, then kills the primary to ensure the *healthy* replica is chosen for promotion.

