output "ad_management_server_ip" {
  value = module.active_directory.ad_management_server_ip
}

output "ad_management_server_dns" {
  value = module.active_directory.ad_management_server_dns
}

output "ad_management_server_password" {
  # this is encrypted, so not sensitive
  value = module.active_directory.ad_management_server_password
}

output "ad_management_private_key" {
  value     = module.active_directory.ad_management_private_key
  sensitive = true
}

output "ca_server_private_key" {
  value     = module.active_directory.ca_server_private_key
  sensitive = true
}

output "directory_admin_password" {
  value     = module.active_directory.directory_admin_password
  sensitive = true
}

output "ml_url" {
  value = module.marklogic.ml_url
}

output "bastion_dns_name" {
  value = module.bastion.bastion_dns_name
}

output "bastion_ssh_keys_bucket" {
  value = module.bastion.ssh_keys_bucket
}

output "bastion_ssh_private_key" {
  value     = tls_private_key.bastion_ssh_key.private_key_openssh
  sensitive = true
}
