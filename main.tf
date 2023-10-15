data "google_client_config" "this" {
}

resource "google_storage_bucket" "bookkeeping" {
  name                        = "khwj-bookkeeping"
  location                    = data.google_client_config.this.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "lakehouse" {
  name                        = "khwj-data"
  location                    = data.google_client_config.this.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_binding" "lakehouse_storage_user" {
  bucket = google_storage_bucket.lakehouse.name
  role   = "roles/storage.objectUser"
  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
  ]
}

resource "google_pubsub_topic" "gmail_notifications" {
  name                       = "gmail_notifications"
  message_retention_duration = "606200s" # 7 days
  # message_retention_duration = "86600s" # 1 day
  labels = {
    project = "personal"
    app     = "bookkeeping"
  }
}

resource "google_pubsub_topic_iam_binding" "gmail_notifications_binding" {
  project = google_pubsub_topic.gmail_notifications.project
  topic   = google_pubsub_topic.gmail_notifications.name
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:gmail-api-push@system.gserviceaccount.com",
  ]
}

resource "google_firestore_database" "default" {
  name                        = "default"
  project                     = data.google_client_config.this.project
  location_id                 = data.google_client_config.this.region
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"
}
