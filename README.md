# hf-tf-module-hcloud

Terraform module for provisioning HobbyFarm virtual machines in Hetzner Cloud.

The module is intended to be used by HobbyFarm's Terraform provider integration.
It creates one Hetzner Cloud server, injects the HobbyFarm SSH public key, and
returns the connection details HobbyFarm needs for the web terminal.

## Features

- Creates one Hetzner Cloud server.
- Creates and assigns one SSH key per server.
- Supports Ubuntu, Debian, and other Hetzner Cloud images.
- Supports optional server labels, firewall IDs, and private networks.
- Supports optional raw extra volumes for lab workloads.
- Returns `public_ip`, `private_ip`, and `hostname` as string outputs.

## Requirements

- Terraform or OpenTofu compatible with provider plugin protocol 6.
- Hetzner Cloud API token with permissions to create servers, SSH keys, and
  volumes.
- HobbyFarm with Terraform support enabled.
- Terraform controller module object pointing to this repository.

## HobbyFarm Module

Example `terraformcontroller.cattle.io/v1` module:

```yaml
apiVersion: terraformcontroller.cattle.io/v1
kind: Module
metadata:
  name: hcloud
  namespace: hobbyfarm
spec:
  git:
    url: https://github.com/msilich/hf-tf-module-hcloud
```

## Basic HobbyFarm Template

Example `VirtualMachineTemplate` config for a simple Ubuntu VM:

```yaml
apiVersion: hobbyfarm.io/v1
kind: VirtualMachineTemplate
metadata:
  name: cx23-ubuntu-24-04
  namespace: hobbyfarm
spec:
  name: cx23 Ubuntu 24.04
  image: ubuntu-24.04
  config_map:
    server_type: cx23
    ssh_username: root
    cloud-config: |
      #cloud-config
      package_update: true
      packages:
        - openssh-server
      runcmd:
        - [ systemctl, enable, --now, ssh ]
```

The corresponding HobbyFarm `Environment` must provide provider-wide settings:

```yaml
environment_specifics:
  executor_image: jggoebel/terraform-executor:v1.0.13
  hcloud_token: <token>
  location: fsn1
  module: hcloud
  poll_interval: 1000ms
```

## Raw Volume Example

Each VM can receive additional unformatted Hetzner Cloud volumes. The module
creates volumes with `hcloud_volume` and attaches them with
`hcloud_volume_attachment`. Volumes are not formatted or mounted by Terraform.

Example template config for two 10 GB raw disks:

```yaml
config_map:
  server_type: cx23
  ssh_username: root
  extra_volume_count: "2"
  extra_volume_size: "10"
  extra_volume_labels: "lab=storage,role=data"
```

Inside the VM, verify the attached disks with:

```bash
lsblk
sudo fdisk -l
```

## Variables

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `hcloud_token` | yes | | Hetzner Cloud API token. |
| `public_key` | yes | | SSH public key generated or supplied by HobbyFarm. |
| `image` | yes | | Hetzner Cloud image, for example `ubuntu-24.04`. |
| `name` | yes | | Server name. HobbyFarm normally supplies this dynamically. |
| `server_type` | yes | | Hetzner Cloud server type, for example `cx23`. |
| `location` | yes | | Hetzner Cloud location, for example `fsn1`, `nbg1`, or `hel1`. |
| `cloud-config` | yes | | Cloud-init user data. |
| `labels` | no | `""` | Server labels as `key=value,key2=value2`. |
| `network_id` | no | `""` | Optional Hetzner Cloud private network ID. |
| `firewall_ids` | no | `""` | Optional comma-separated firewall IDs. |
| `poll_interval` | no | `1000ms` | Hetzner provider polling interval. |
| `poll_function` | no | `exponential` | Provider polling function, usually `constant` or `exponential`. |
| `extra_volume_count` | no | `0` | Number of additional raw volumes to attach. |
| `extra_volume_size` | no | `10` | Size of each additional volume in GB. |
| `extra_volume_labels` | no | `""` | Extra volume labels as `key=value,key2=value2`. |

All variables are strings because HobbyFarm passes template and environment
settings through Kubernetes ConfigMaps.

## Outputs

| Name | Description |
| --- | --- |
| `public_ip` | Public IPv4 address used by HobbyFarm Shell. |
| `private_ip` | Private network IP if a private network is attached, otherwise public IPv4. |
| `hostname` | Hetzner Cloud server name. |
| `extra_volume_ids` | Comma-separated IDs of additional volumes. Empty when no extra volumes exist. |
| `extra_volume_names` | Comma-separated names of additional volumes. Empty when no extra volumes exist. |

The extra volume outputs are strings to stay compatible with HobbyFarm's
Terraform output parser.

## Notes

- Extra volumes use `location` plus separate `hcloud_volume_attachment`, which
  is the recommended pattern for attaching multiple volumes to one server.
- `automount = false` is used so lab workloads can consume the devices as raw
  block devices.
- Deleting the HobbyFarm session should delete the Terraform state resource,
  which triggers Terraform destroy for the server, SSH key, volumes, and
  attachments.
- Wait for destroy to finish before immediately starting the same scenario
  again.
