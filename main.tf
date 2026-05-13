variable "hcloud_token" {}
variable "public_key" {}
variable "image" {}
variable "name" {}
variable "server_type" {}
variable "location" {}
variable "cloud-config" {}
variable "labels" {
  type        = string
  default     = ""
  description = "Optional labels for the server in 'key1=value1,key2=value2' format"
}
variable "network_id" {
  type        = string
  default     = ""
  description = "Optional network ID for the server"
}
variable "firewall_ids" {
  type        = string
  default     = ""
  description = "Optional firewall IDs for the server, comma-separated"
}
variable "poll_interval" {
  type        = string
  default     = "1000ms"
  description = "configures the interval in which actions are polled by the client. Increase if Rate Limiting Errors occur"
}
variable "poll_function" {
  type        = string
  default     = "exponential"
  description = "Configures the type of function to be used during the polling. Valid values are constant and exponential"
}
variable "extra_volume_count" {
  type        = string
  default     = "0"
  description = "Number of additional Hetzner Cloud volumes to attach to the server"
}
variable "extra_volume_size" {
  type        = string
  default     = "10"
  description = "Size in GB for each additional Hetzner Cloud volume"
}
variable "extra_volume_labels" {
  type        = string
  default     = ""
  description = "Optional labels for additional volumes in 'key1=value1,key2=value2' format"
}


locals {
  labels_map              = length(var.labels) > 0 ? { for pair in split(",", var.labels) : split("=", pair)[0] => split("=", pair)[1] } : {}
  firewall_ids_list       = length(var.firewall_ids) > 0 ? split(",", var.firewall_ids) : []
  extra_volume_count      = tonumber(var.extra_volume_count)
  extra_volume_size       = tonumber(var.extra_volume_size)
  extra_volume_labels_map = length(var.extra_volume_labels) > 0 ? { for pair in split(",", var.extra_volume_labels) : split("=", pair)[0] => split("=", pair)[1] } : {}
}

terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45.0"
    }
  }
  required_version = ">= 0.14.0"
}

#Configure the Hetzner Cloud Provider
provider "hcloud" {
  token         = var.hcloud_token
  poll_interval = var.poll_interval
  poll_function = var.poll_function
}

# Create a new SSH key
resource "hcloud_ssh_key" "key" {
  name       = "${var.name}-key"
  public_key = var.public_key
}

# Create a new server running debian
resource "hcloud_server" "node1" {
  name        = var.name
  image       = var.image
  location    = var.location
  server_type = var.server_type
  ssh_keys    = ["${var.name}-key"]
  user_data   = var.cloud-config

  labels       = local.labels_map
  firewall_ids = length(local.firewall_ids_list) > 0 ? local.firewall_ids_list : null

  dynamic "network" {
    for_each = var.network_id != "" ? [var.network_id] : []
    content {
      network_id = network.value
    }
  }
}

resource "hcloud_volume" "extra" {
  count = local.extra_volume_count

  name     = "${var.name}-data-${count.index + 1}"
  size     = local.extra_volume_size
  location = var.location
  labels   = local.extra_volume_labels_map
}

resource "hcloud_volume_attachment" "extra" {
  count = local.extra_volume_count

  volume_id = hcloud_volume.extra[count.index].id
  server_id = hcloud_server.node1.id
  automount = false
}

output "private_ip" {
  value = (
    length(hcloud_server.node1.network) > 0
    ? tolist(hcloud_server.node1.network)[0].ip
    : hcloud_server.node1.ipv4_address
  )
}

output "public_ip" {
  value = hcloud_server.node1.ipv4_address
}

output "hostname" {
  value = hcloud_server.node1.name
}

output "extra_volume_ids" {
  value = join(",", [for volume in hcloud_volume.extra : tostring(volume.id)])
}

output "extra_volume_names" {
  value = join(",", [for volume in hcloud_volume.extra : volume.name])
}
