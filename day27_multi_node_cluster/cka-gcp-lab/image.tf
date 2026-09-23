data "google_compute_image" "cka_node" {
  family  = var.node_image_family
  project = var.project_id
}
