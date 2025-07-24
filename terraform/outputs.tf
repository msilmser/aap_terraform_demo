output "controller_ip" {
  value = libvirt_domain.aap_controller.network_interface[0].addresses[0]
}

output "hub_ip" {
  value = libvirt_domain.aap_hub.network_interface[0].addresses[0]
}

output "database_ip" {
  value = libvirt_domain.aap_database.network_interface[0].addresses[0]
}

output "network_cidr" {
  value = libvirt_network.aap_network.addresses[0]
}