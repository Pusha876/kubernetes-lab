resource "google_compute_network" "cka_vpc" {
  name                    = "cka-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cka_subnet" {
  name          = "cka-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.cka_vpc.id
}