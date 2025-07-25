output "controller_ip" {
  value = length(libvirt_domain.aap_controller.network_interface[0].addresses) > 0 ? libvirt_domain.aap_controller.network_interface[0].addresses[0] : "DHCP - check with 'virsh domifaddr aap-controller'"
}

output "hub_ip" {
  value = length(libvirt_domain.aap_hub.network_interface[0].addresses) > 0 ? libvirt_domain.aap_hub.network_interface[0].addresses[0] : "DHCP - check with 'virsh domifaddr aap-hub'"
}

output "database_ip" {
  value = length(libvirt_domain.aap_database.network_interface[0].addresses) > 0 ? libvirt_domain.aap_database.network_interface[0].addresses[0] : "DHCP - check with 'virsh domifaddr aap-database'"
}

output "network_cidr" {
  value = libvirt_network.aap_network.addresses[0]
}