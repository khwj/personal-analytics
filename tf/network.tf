resource "google_compute_network" "this" {
  name                    = var.network_name
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "private1" {
  name          = "private1"
  ip_cidr_range = var.network_ip_cidr_range
  region        = data.google_client_config.this.region
  network       = google_compute_network.this.id
}
