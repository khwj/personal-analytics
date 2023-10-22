resource "google_secret_manager_secret" "gmail_sync_sa_key" {
  secret_id = var.gmail_sync_service_account_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "gmail_sync_connect_sa_key" {
  secret      = google_secret_manager_secret.gmail_sync_sa_key.id
  secret_data = base64decode(google_service_account_key.gmail_sync_connect_sa_key.private_key)
}