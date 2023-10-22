resource "google_firestore_database" "default" {
  name                        = var.gmail_sync_firestore_db
  project                     = data.google_client_config.this.project
  location_id                 = data.google_client_config.this.region
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"
}
