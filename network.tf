resource "google_compute_network" "this" {
  name                    = "main"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "private1" {
  name          = "private1"
  ip_cidr_range = "10.0.1.0/24"
  region        = data.google_client_config.this.region
  network       = google_compute_network.this.id
}
