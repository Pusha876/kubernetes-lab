resource "google_compute_firewall" "allow_ssh" {
  name    = "cka-allow-ssh"
  network = google_compute_network.cka_vpc.name

  direction = "INGRESS"

  source_ranges = var.ssh_source_ranges

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["cka-node"]
}

resource "google_compute_firewall" "kubernetes_control_plane" {
  name    = "cka-kubernetes-control-plane"
  network = google_compute_network.cka_vpc.name

  direction = "INGRESS"

  source_ranges = ["10.10.0.0/24"]

  target_tags = ["cka-master"]

  allow {
    protocol = "tcp"
    ports = [
      "6443",
      "2379-2380",
      "10250",
      "10257",
      "10259"
    ]
  }
}

resource "google_compute_firewall" "kubernetes_workers" {
  name    = "cka-kubernetes-workers"
  network = google_compute_network.cka_vpc.name

  direction = "INGRESS"

  source_ranges = ["10.10.0.0/24"]

  target_tags = ["cka-node"]

  allow {
    protocol = "tcp"

    ports = [
      "10250",
      "10256",
      "30000-32767"
    ]
  }

  allow {
    protocol = "udp"

    ports = [
      "30000-32767"
    ]
  }
}

resource "google_compute_firewall" "kubernetes_internal" {
  name    = "cka-kubernetes-internal"
  network = google_compute_network.cka_vpc.name

  direction = "INGRESS"

  source_ranges = [
    "10.10.0.0/24"
  ]

  target_tags = ["cka-node"]

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }
}