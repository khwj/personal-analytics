data "archive_file" "gmail_sync_source" {
  type       = "zip"
  source_dir = "gmail_sync/"
  excludes = [
    "__pycache__",
    ".pytest_cache",
    ".vscode",
    ".coveragerc",
    "requirements.test.txt",
    "tests",
    "venv",
  ]
  output_path = "/tmp/gmail_sync.zip"
}

resource "google_storage_bucket_object" "gmail_sync_source" {
  name   = "function-source/gmail_sync.zip"
  bucket = google_storage_bucket.bookkeeping.name
  source = data.archive_file.gmail_sync_source.output_path
}

data "google_secret_manager_secret" "gmail_sync_client_secret" {
  secret_id = "gmail-sync-client-secret"
}

resource "google_secret_manager_secret" "gmail_sync_sa_key" {
  secret_id = "gmail-sync-sa-key"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "gmail_sync_sa_key" {
  secret      = google_secret_manager_secret.gmail_sync_sa_key.id
  secret_data = base64decode(google_service_account_key.gmail_sync_sa_key.private_key)
}

resource "google_secret_manager_secret_iam_binding" "gmail_sync_client_secret_sa_binding" {
  project   = data.google_secret_manager_secret.gmail_sync_client_secret.project
  secret_id = data.google_secret_manager_secret.gmail_sync_client_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
    "serviceAccount:${google_service_account.gmail_sync_download_function_source.email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "gmail_sync_sa_key_sa_binding" {
  project   = google_secret_manager_secret.gmail_sync_sa_key.project
  secret_id = google_secret_manager_secret.gmail_sync_sa_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
    "serviceAccount:${google_service_account.gmail_sync_download_function_source.email}",
  ]
}
