resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
  name      = var.hostname
  node_name = var.proxmox_node

  agent {
    enabled = true
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.dedicated_memory
    floating = var.floating_memory
  }

  disk {
    datastore_id = "local-zfs"
    import_from  = var.disk_import_from
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  startup {
    order      = var.start_order
    up_delay   = var.up_delay
    down_delay = var.down_delay
  }

  initialization {
    # uncomment and specify the datastore for cloud-init disk if default `local-lvm` is not available
    datastore_id = "local-zfs"

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
  }

  network_device {
    bridge = "vmbr0"
  }
}

output "vm_ipv4_address" {
  value = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses[1][0]
}
