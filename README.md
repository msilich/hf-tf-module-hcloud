# hf-tf-module-hcloud

Terraform module for HobbyFarm VMs on Hetzner Cloud.

## Optional extra volumes

The module can attach additional raw Hetzner Cloud volumes to the server. They
are not formatted or mounted by Terraform, so labs can use them as raw block
devices, for example as Ceph OSD disks.

Variables:

- `extra_volume_count`: number of additional volumes, default `0`
- `extra_volume_size`: size of each additional volume in GB, default `10`
- `extra_volume_labels`: optional comma-separated labels, for example `lab=ceph,role=osd`

Example HobbyFarm template config:

```yaml
config_map:
  server_type: cx23
  ssh_username: root
  extra_volume_count: "2"
  extra_volume_size: "10"
  extra_volume_labels: "lab=ceph,role=osd"
```
