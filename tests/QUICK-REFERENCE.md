# Quick Reference Guide - Chaos Tests

## Test Files Quick Index

```
tests/
├── 01-pod-failure.yaml           # Pod Failure (5min) - FAIL
├── 02-pod-kill.yaml              # Pod Kill - PASS ✓
├── 03-pod-oom.yaml               # Out of Memory - FAIL
├── 04-kill-postgres-process.yaml # Kill Process - FAIL
├── 05-network-partition.yaml     # Network Partition - FAIL
├── 06-network-bandwidth.yaml     # Bandwidth Limit (1mbps) - FAIL
├── 07-network-delay.yaml         # Network Latency (500ms) - FAIL
├── 08-network-loss.yaml          # Packet Loss (100%) - PASS ✓
├── 09-network-duplicate.yaml     # Packet Duplicate (50%) - PASS ✓
├── 10-network-corrupt.yaml       # Packet Corrupt (50%) - FAIL
├── 11-time-offset.yaml           # Time Offset (-2h) - FAIL
├── 12-dns-error.yaml             # DNS Error - PASS ✓
├── 13-io-latency.yaml            # I/O Latency (500ms) - FAIL
├── 14-io-fault.yaml              # I/O Fault (EIO) - FAIL
├── 15-io-attr-override.yaml      # Read-only Files - FAIL
├── 16-io-mistake.yaml            # Data Corruption - FAIL
├── 17-node-reboot.yaml           # Node Reboot - FAIL
├── 18-stress-cpu-primary.yaml    # CPU Stress (90%) - PASS ✓
└── 19-stress-memory-replica.yaml # Memory Stress (800Mi) - PASS ✓
```

## One-Liner Commands

### Single Test Execution
```bash
# Apply test
kubectl apply -f tests/02-pod-kill.yaml

# Watch effect
watch kubectl get pods -n demo

# Cleanup
kubectl delete -f tests/02-pod-kill.yaml
```

### Quick Status Check
```bash
# Cluster status
kubectl get postgres,pods -n demo

# Pod roles
kubectl get pods -n demo -L kubedb.com/role

# Replication status
kubectl exec -n demo $(kubectl get pods -n demo -l kubedb.com/role=primary -o name | head -1) -- psql -c "SELECT * FROM pg_stat_replication;"
```

### Quick Monitoring
```bash
# Watch roles
watch 'kubectl get pods -n demo -o custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.kubedb\\.com/role,STATUS:.status.phase'

# Stream logs
kubectl logs -n demo -l app.kubernetes.io/instance=pg-ha-cluster -c pg-coordinator -f

# Check events
kubectl get events -n demo --field-selector involvedObject.name=pg-ha-cluster --sort-by='.lastTimestamp'
```

## Test Categories

### 🔴 Critical Tests (Expect Failure)
- `01-pod-failure.yaml` - Extended pod failure
- `05-network-partition.yaml` - Split-brain risk
- `13-io-latency.yaml` - Storage degradation
- `17-node-reboot.yaml` - Datacenter outage

### 🟢 Resilience Tests (Expect Pass)
- `02-pod-kill.yaml` - Rapid failover
- `08-network-loss.yaml` - Complete network failure
- `12-dns-error.yaml` - DNS resilience
- `18-stress-cpu-primary.yaml` - CPU pressure

### 🟡 Performance Tests
- `06-network-bandwidth.yaml` - Congestion
- `07-network-delay.yaml` - High latency
- `19-stress-memory-replica.yaml` - Memory pressure

## Common Scenarios

### Scenario 1: Primary Pod Crash
```bash
# Run test
kubectl apply -f tests/02-pod-kill.yaml

# Expected: Failover in 2-10 seconds
# Watch: kubectl get pods -n demo -w
```

### Scenario 2: Network Issues
```bash
# Partition test
kubectl apply -f tests/05-network-partition.yaml

# Loss test
kubectl apply -f tests/08-network-loss.yaml

# Expected: Failover triggered
```

### Scenario 3: Storage Problems
```bash
# I/O latency
kubectl apply -f tests/13-io-latency.yaml

# I/O faults
kubectl apply -f tests/14-io-fault.yaml

# Expected: Degraded performance
```

## Validation Checklist

After each test:
- [ ] All pods return to Running state
- [ ] One pod is labeled as primary
- [ ] Two pods are labeled as standby
- [ ] Replication is active (check pg_stat_replication)
- [ ] Database is accessible
- [ ] No data loss
- [ ] Chaos experiment cleaned up

## Emergency Procedures

### If Cluster Is Stuck
```bash
# Check operator logs
kubectl logs -n kubedb -l app.kubernetes.io/name=kubedb-ops-manager --tail=100

# Check coordinator logs
kubectl logs -n demo -l app.kubernetes.io/instance=pg-ha-cluster -c pg-coordinator --tail=100

# Force cleanup
kubectl delete podchaos,networkchaos,iochaos --all -n chaos-mesh
```

### If No Primary Exists
```bash
# Check all pods
kubectl get pods -n demo -o wide

# Check coordinator logs for leader election
kubectl logs -n demo <pod-name> -c pg-coordinator

# May need force failover (check KubeDB docs)
```

### If Data Loss Suspected
```bash
# Check WAL position
kubectl exec -n demo $PRIMARY_POD -- psql -c "SELECT pg_current_wal_lsn();"

# Check replication lag
kubectl exec -n demo $PRIMARY_POD -- psql -c "SELECT * FROM pg_stat_replication;"

# Restore from backup if needed
```

## Performance Benchmarking

### Before Tests
```bash
# Create test data
kubectl exec -n demo $PRIMARY_POD -- psql << EOF
CREATE TABLE benchmark (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO benchmark (data) SELECT md5(random()::text) FROM generate_series(1,10000);
EOF

# Measure baseline
time kubectl exec -n demo $PRIMARY_POD -- psql -c "SELECT COUNT(*) FROM benchmark;"
```

### During Tests
```bash
# Monitor query performance
while true; do
  time kubectl exec -n demo $PRIMARY_POD -- psql -c "SELECT COUNT(*) FROM benchmark;" 2>&1 | grep real
  sleep 5
done
```

### After Tests
```bash
# Verify data integrity
kubectl exec -n demo $PRIMARY_POD -- psql -c "SELECT COUNT(*) FROM benchmark;"

# Check for corruption
kubectl exec -n demo $PRIMARY_POD -- psql -c "SELECT pg_is_in_recovery();"
```

## Useful Aliases

Add to your `.bashrc` or `.zshrc`:

```bash
# Alias for quick access
alias kgpg='kubectl get postgres -n demo'
alias kgpod='kubectl get pods -n demo'
alias kdesc='kubectl describe'
alias klogs='kubectl logs -n demo'
alias kexec='kubectl exec -n demo -it'

# Postgres specific
alias pgprimary='kubectl get pods -n demo -l kubedb.com/role=primary'
alias pgstandby='kubectl get pods -n demo -l kubedb.com/role=standby'
alias pgrep='kubectl exec -n demo $(kubectl get pods -n demo -l kubedb.com/role=primary -o name | head -1) -- psql -c "SELECT * FROM pg_stat_replication;"'

# Chaos testing
alias chaoslist='kubectl get podchaos,networkchaos,iochaos,stresschaos -n chaos-mesh'
alias chaosclean='kubectl delete podchaos,networkchaos,iochaos,stresschaos,timechaos,dnschaos -n chaos-mesh --all'
```

## Test Timing Guidelines

| Test Type | Duration | Recovery Wait | Total Time |
|-----------|----------|---------------|------------|
| Pod Kill | 30s | 60s | 2 min |
| Pod Failure | 5m | 2m | 7 min |
| Network | 5-10m | 2m | 7-12 min |
| I/O Chaos | 5-10m | 3m | 8-13 min |
| Stress | 10m | 2m | 12 min |
| Node Reboot | 30s | 5m | 6 min |

**Total for all tests**: ~3-4 hours (sequential)

## Troubleshooting Quick Fixes

| Issue | Quick Fix |
|-------|-----------|
| Test not applying | `kubectl describe <chaos-type> -n chaos-mesh` |
| Pod stuck in terminating | `kubectl delete pod --force --grace-period=0` |
| No chaos effect | Check Chaos Mesh controller logs |
| Cluster not recovering | Check KubeDB operator logs |
| Permission denied | Check RBAC for chaos-mesh SA |

## Resource Requirements

Minimum cluster resources for testing:
- **Nodes**: 3 worker nodes
- **CPU**: 2 cores per node (6 total)
- **Memory**: 4GB per node (12GB total)
- **Storage**: 10GB per node (30GB total)
- **Network**: 1Gbps between nodes

## Safety Checklist

Before running tests:
- [ ] Backup your data
- [ ] Not in production environment
- [ ] Monitoring is set up
- [ ] Team is notified
- [ ] Rollback plan ready
- [ ] Time allocated (3-4 hours for full suite)
- [ ] Chaos Mesh installed and working
- [ ] PostgreSQL cluster is healthy

## Quick Debug Commands

```bash
# Everything about PostgreSQL
kubectl get all,postgres,postgresopsrequests -n demo

# All chaos experiments
kubectl get chaos -n chaos-mesh

# Recent events
kubectl get events -n demo --sort-by='.lastTimestamp' | tail -20

# Pod details
kubectl get pods -n demo -o wide -L kubedb.com/role

# Coordinator status
kubectl logs -n demo -l app.kubernetes.io/instance=pg-ha-cluster -c pg-coordinator --tail=50

# Database connectivity
kubectl run -it --rm pg-client --image=postgres:16 --restart=Never -n demo -- psql -h pg-ha-cluster.demo.svc.cluster.local -U postgres
```

## Success Criteria Summary

| Test | Success Criteria |
|------|------------------|
| Pod Kill | Failover < 10s, no data loss |
| Network Loss | Failover triggered, recovery complete |
| Network Partition | Split-brain prevented |
| I/O Latency | Queries slower but functional |
| CPU Stress | Queries complete, no crash |
| Memory Stress | No OOM, performance degraded |

---

**Remember**: These tests are designed to break things. Document everything and learn from failures!
