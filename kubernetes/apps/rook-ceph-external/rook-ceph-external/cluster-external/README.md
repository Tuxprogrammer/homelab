Proxmox Ceph Dashboard install:
https://forum.proxmox.com/threads/nautilus-activating-ceph-dashboard.85961/

Proxmox Ceph Radosgw install:
https://pve.proxmox.com/wiki/User:Grin/Ceph_Object_Gateway

Proxmox Radosgw Fixes:
https://forum.proxmox.com/threads/ceph-object-rgw.160958/


First, export the ceph cluster (create users and credentials for rook):
https://rook.io/docs/rook/v1.16/CRDs/Cluster/external-cluster/provider-export/

```
/usr/bin/python3 create-external-cluster-resources.py --rbd-data-pool-name ceph_shared --cephfs-filesystem-name cephfs_store2 --rgw-endpoint s3.tuxhpc.net:7480 --namespace rook-ceph-external --format bash --ceph-conf ceph.conf --dry-run
Execute: 'ceph fs ls'
Execute: 'ceph fsid'
Execute: 'ceph quorum_status'
Execute: 'ceph auth get-or-create client.healthchecker mon allow r, allow command quorum_status, allow command version mgr allow command config osd allow rwx pool=default.rgw.meta, allow r pool=.rgw.root, allow rw pool=default.rgw.control, allow rx pool=default.rgw.log, allow x pool=default.rgw.buckets.index'
Execute: 'ceph mgr services'
Execute: 'ceph auth get-or-create client.csi-rbd-node mon profile rbd, allow command 'osd blocklist' osd profile rbd'
Execute: 'ceph auth get-or-create client.csi-rbd-provisioner mon profile rbd, allow command 'osd blocklist' mgr allow rw osd profile rbd'
Execute: 'ceph status'
Execute: 'ceph radosgw-admin user create --uid rgw-admin-ops-user --display-name Rook RGW Admin Ops user --caps buckets=*;users=*;usage=read;metadata=read;zone=read'
export NAMESPACE=rook-ceph-external
export ROOK_EXTERNAL_USERNAME=client.healthchecker
export CEPHFS_FS_NAME=cephfs_store2
export RGW_ENDPOINT=10.1.2.13:7480
export RBD_POOL_NAME=ceph_shared
export RGW_POOL_PREFIX=default
```

Second import the cluster to rook with kubernetes resources:
https://rook.io/docs/rook/v1.16/CRDs/Cluster/external-cluster/consumer-import/
https://github.com/rook/rook/blob/release-1.16/deploy/examples/import-external-cluster.sh
