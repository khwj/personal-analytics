resource "google_service_account" "scheduler" {
  account_id   = "scheduler"
  display_name = "Service Account for Cloud Schelduler"
}

resource "google_service_account" "gmail_sync" {
  account_id   = "gmail-sync-functions"
  display_name = "Gmail Sync Cloud Functions Service Account"
}

resource "time_rotating" "gmail_sync_sa_key" {
  rotation_days = 30
}

resource "google_service_account_key" "gmail_sync_sa_key" {
  service_account_id = google_service_account.gmail_sync.name

  keepers = {
    rotation_time = time_rotating.gmail_sync_sa_key.rotation_rfc3339
  }
}

resource "google_project_iam_binding" "datastore_user" {
  project = data.google_client_config.this.project
  role    = "roles/datastore.user"
  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
  ]
}

output "gmail_sync_sa_key" {
  sensitive = true
  value     = google_service_account_key.gmail_sync_sa_key.private_key
}
