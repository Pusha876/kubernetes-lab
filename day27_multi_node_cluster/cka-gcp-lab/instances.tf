locals {
  machine_type = "e2-medium"

  image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

resource "google_compute_instance" "master" {
  name         = "cka-master"
  machine_type = local.machine_type
  zone         = var.zone

  tags = [
    "cka-node",
    "cka-master"
  ]

  boot_disk {
    initialize_params {
      image = local.image
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.cka_subnet.id

    access_config {}
  }
}

resource "google_compute_instance" "worker_1" {
  name         = "cka-worker-1"
  machine_type = local.machine_type
  zone         = var.zone

  tags = [
    "cka-node",
    "cka-worker"
  ]

  boot_disk {
    initialize_params {
      image = local.image
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.cka_subnet.id

    access_config {}
  }
}

resource "google_compute_instance" "worker_2" {
  name         = "cka-worker-2"
  machine_type = local.machine_type
  zone         = var.zone

  tags = [
    "cka-node",
    "cka-worker"
  ]

  boot_disk {
    initialize_params {
      image = local.image
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.cka_subnet.id

    access_config {}
  }
}