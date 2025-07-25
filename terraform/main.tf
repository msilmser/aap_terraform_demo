terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Pool created by setup.sh - using pool name directly

resource "libvirt_volume" "controller_volume" {
  name   = "aap-controller.qcow2"
  pool   = "aap-pool"
  source = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-9-latest.x86_64.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "hub_volume" {
  name   = "aap-hub.qcow2"
  pool   = "aap-pool"
  source = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-9-latest.x86_64.qcow2"
  format = "qcow2"
}

resource "libvirt_volume" "database_volume" {
  name   = "aap-database.qcow2"
  pool   = "aap-pool"
  source = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-9-latest.x86_64.qcow2"
  format = "qcow2"
}

resource "libvirt_network" "aap_network" {
  name      = "aap-network"
  mode      = "nat"
  domain    = "aap.local"
  addresses = ["192.168.100.0/24"]
  autostart = true

  dhcp {
    enabled = true
  }

  dns {
    enabled    = true
    local_only = false
  }
}

resource "libvirt_cloudinit_disk" "controller_init" {
  name = "controller-init.iso"
  pool = "aap-pool"
  user_data = templatefile("${path.module}/cloud-init/controller-user-data.yaml", {
    hostname = "aap-controller"
  })
  network_config = file("${path.module}/cloud-init/network-config.yaml")
}

resource "libvirt_cloudinit_disk" "hub_init" {
  name = "hub-init.iso"
  pool = "aap-pool"
  user_data = templatefile("${path.module}/cloud-init/hub-user-data.yaml", {
    hostname = "aap-hub"
  })
  network_config = file("${path.module}/cloud-init/network-config.yaml")
}

resource "libvirt_cloudinit_disk" "database_init" {
  name = "database-init.iso"
  pool = "aap-pool"
  user_data = templatefile("${path.module}/cloud-init/database-user-data.yaml", {
    hostname = "aap-database"
  })
  network_config = file("${path.module}/cloud-init/network-config.yaml")
}

resource "libvirt_domain" "aap_controller" {
  name   = "aap-controller"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.controller_init.id

  network_interface {
    network_id     = libvirt_network.aap_network.id
    hostname       = "aap-controller"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.controller_volume.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource "libvirt_domain" "aap_hub" {
  name   = "aap-hub"
  memory = "4096"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.hub_init.id

  network_interface {
    network_id     = libvirt_network.aap_network.id
    hostname       = "aap-hub"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.hub_volume.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

resource "libvirt_domain" "aap_database" {
  name   = "aap-database"
  memory = "2048"
  vcpu   = 2

  cloudinit = libvirt_cloudinit_disk.database_init.id

  network_interface {
    network_id     = libvirt_network.aap_network.id
    hostname       = "aap-database"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.database_volume.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}