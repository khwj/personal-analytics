provider "google" {
  project        = var.gcp_project
  region         = var.gcp_region
  zone           = var.gcp_zone
  default_labels = var.default_labels
}
