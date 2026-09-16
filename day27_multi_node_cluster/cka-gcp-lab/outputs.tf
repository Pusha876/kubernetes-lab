output "master_external_ip" {
  value = google_compute_instance.master.network_interface[0].access_config[0].nat_ip
}

output "master_internal_ip" {
  value = google_compute_instance.master.network_interface[0].network_ip
}

output "worker_1_external_ip" {
  value = google_compute_instance.worker_1.network_interface[0].access_config[0].nat_ip
}

output "worker_1_internal_ip" {
  value = google_compute_instance.worker_1.network_interface[0].network_ip
}

output "worker_2_external_ip" {
  value = google_compute_instance.worker_2.network_interface[0].access_config[0].nat_ip
}

output "worker_2_internal_ip" {
  value = google_compute_instance.worker_2.network_interface[0].network_ip
}