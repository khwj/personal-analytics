resource "google_service_account" "gmail_sync_download_function" {
  account_id   = "gmail-sync-download-function"
  display_name = "Service account for Gmail Sync Download Attachments function"
}

resource "google_service_account" "scheduler" {
  account_id   = "scheduler"
  display_name = "Service Account for Cloud Schelduler"
}

resource "google_service_account" "gmail_sync_connect" {
  account_id   = "gmail-sync-connect-function"
  display_name = "Gmail Sync Cloud Functions Service Account"
}

resource "time_rotating" "gmail_sync_connect_sa_key" {
  rotation_days = 30
}

resource "google_service_account_key" "gmail_sync_connect_sa_key" {
  service_account_id = google_service_account.gmail_sync_connect.name

  keepers = {
    rotation_time = time_rotating.gmail_sync_connect_sa_key.rotation_rfc3339
  }
}

resource "google_project_iam_binding" "datastore_user" {
  project = data.google_client_config.this.project
  role    = "roles/datastore.user"
  members = [
    "serviceAccount:${google_service_account.gmail_sync_connect.email}",
  ]
}

resource "google_cloud_run_service_iam_binding" "gmail_sync_download_invoker" {
  project  = google_cloudfunctions2_function.gmail_sync_download.project
  location = google_cloudfunctions2_function.gmail_sync_download.location
  service  = google_cloudfunctions2_function.gmail_sync_download.name
  role     = "roles/run.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_download_function.email}",
  ]
}

resource "google_cloudfunctions2_function_iam_binding" "gmail_sync_download_invoker" {
  project        = google_cloudfunctions2_function.gmail_sync_download.project
  location       = google_cloudfunctions2_function.gmail_sync_download.location
  cloud_function = google_cloudfunctions2_function.gmail_sync_download.name
  role           = "roles/cloudfunctions.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_download_function.email}",
  ]
}

resource "google_cloud_run_service_iam_binding" "gmail_sync_refresh_token_invoker" {
  project  = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.project
  location = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.location
  service  = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.name
  role     = "roles/run.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_connect.email}",
    "serviceAccount:${google_service_account.scheduler.email}",
  ]
}

resource "google_cloudfunctions2_function_iam_binding" "gmail_sync_refresh_token_invoker" {
  project        = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.project
  location       = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.location
  cloud_function = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.name
  role           = "roles/cloudfunctions.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_connect.email}",
    "serviceAccount:${google_service_account.scheduler.email}",
  ]
}

resource "google_cloud_run_service_iam_binding" "gmail_sync_renew_watch_invoker" {
  project  = google_cloudfunctions2_function.gmail_sync_renew_watch.project
  location = google_cloudfunctions2_function.gmail_sync_renew_watch.location
  service  = google_cloudfunctions2_function.gmail_sync_renew_watch.name
  role     = "roles/run.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_connect.email}",
    "serviceAccount:${google_service_account.scheduler.email}",
  ]
}

resource "google_cloudfunctions2_function_iam_binding" "gmail_sync_renew_watch_invoker" {
  project        = google_cloudfunctions2_function.gmail_sync_renew_watch.project
  location       = google_cloudfunctions2_function.gmail_sync_renew_watch.location
  cloud_function = google_cloudfunctions2_function.gmail_sync_renew_watch.name
  role           = "roles/cloudfunctions.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_connect.email}",
    "serviceAccount:${google_service_account.scheduler.email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "gmail_sync_client_secret_sa_binding" {
  project   = data.google_secret_manager_secret.gmail_sync_connect_client_secret.project
  secret_id = data.google_secret_manager_secret.gmail_sync_connect_client_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.gmail_sync_connect.email}",
    "serviceAccount:${google_service_account.gmail_sync_download_function.email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "gmail_sync_sa_key_sa_binding" {
  project   = google_secret_manager_secret.gmail_sync_sa_key.project
  secret_id = google_secret_manager_secret.gmail_sync_sa_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.gmail_sync_connect.email}",
    "serviceAccount:${google_service_account.gmail_sync_download_function.email}",
  ]
}

resource "google_storage_bucket_iam_binding" "lakehouse_storage_user" {
  bucket = google_storage_bucket.lakehouse.name
  role   = "roles/storage.objectUser"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_connect.email}",
  ]
}

resource "google_pubsub_topic_iam_binding" "gmail_notifications_binding" {
  project = google_pubsub_topic.gmail_notifications.project
  topic   = google_pubsub_topic.gmail_notifications.name
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:gmail-api-push@system.gserviceaccount.com",
  ]
}