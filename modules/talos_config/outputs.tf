output "contorller_user_data" {
  value = data.talos_machine_configuration.controlplane.machine_configuration
}

output "worker_user_data" {
  value = data.talos_machine_configuration.worker.machine_configuration
}

output "client_configuration" {
  value = talos_machine_secrets.this.client_configuration
}
