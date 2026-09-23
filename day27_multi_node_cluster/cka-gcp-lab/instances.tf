locals {
  machine_type = "e2-medium"
}

resource "google_compute_instance_template" "cka_node" {
  name_prefix  = "cka-node-"
  machine_type = local.machine_type
  region       = var.region

  tags = ["cka-node"]

  disk {
    source_image = data.google_compute_image.cka_node.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.cka_subnet.id

    access_config {}
  }

  metadata_startup_script = file("${path.module}/scripts/node-bootstrap.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_from_template" "master" {
  name                     = "cka-master"
  zone                     = var.zone
  source_instance_template = google_compute_instance_template.cka_node.self_link

  tags = ["cka-node", "cka-master"]
}

resource "google_compute_instance_from_template" "worker_1" {
  name                     = "cka-worker-1"
  zone                     = var.zone
  source_instance_template = google_compute_instance_template.cka_node.self_link

  tags = ["cka-node", "cka-worker"]
}

resource "google_compute_instance_from_template" "worker_2" {
  name                     = "cka-worker-2"
  zone                     = var.zone
  source_instance_template = google_compute_instance_template.cka_node.self_link

  tags = ["cka-node", "cka-worker"]
}
