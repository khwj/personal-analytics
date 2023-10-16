resource "google_service_account" "gmail_sync_download_function_source" {
  account_id   = "gmail-sync-download-function"
  display_name = "Service account for Gmail Sync Download Attachments function"
}

data "archive_file" "gmail_sync_download_function_source" {
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
  output_path = "/tmp/gmail_sync_download.zip"
}

resource "google_storage_bucket_object" "gmail_sync_download_function_source" {
  name   = "function-source/gmail-sync-download.zip"
  bucket = google_storage_bucket.bookkeeping.name
  source = data.archive_file.gmail_sync_download_function_source.output_path
}

resource "google_cloudfunctions2_function" "gmail_sync_download" {
  name     = "gmail-sync-download"
  location = "asia-southeast1"

  build_config {
    runtime     = "python311"
    entry_point = "download_attachments_handler"
    source {
      storage_source {
        bucket = google_storage_bucket.bookkeeping.name
        object = google_storage_bucket_object.gmail_sync_download_function_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    min_instance_count    = 0
    available_memory      = "256M"
    service_account_email = google_service_account.gmail_sync_download_function_source.email

    environment_variables = {
      FIRESTORE_COLLECTION           = "gmail_sync"
      FIRESTORE_DB                   = "default"
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GMAIL_LABEL_ID                 = "Label_4739348339418472707"
      GMAIL_HISTORY_TYPES            = "messageAdded,labelAdded"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = "google_credentials"

      DESTINATION_BUCKET_NAME        = "khwj-data"
      DESTINATION_BASE_PATH          = "bronze"
      SYNC_STATE_DOCUMENT_ID         = "last_sync_state"
    }

    secret_volumes {
      mount_path = "/etc/secrets/sa_keys"
      project_id = google_secret_manager_secret.gmail_sync_sa_key.project
      secret     = google_secret_manager_secret.gmail_sync_sa_key.secret_id
    }

    secret_volumes {
      mount_path = "/etc/secrets/client_secrets"
      project_id = data.google_secret_manager_secret.gmail_sync_client_secret.project
      secret     = data.google_secret_manager_secret.gmail_sync_client_secret.secret_id
    }
  }

  event_trigger {
    trigger_region        = "asia-southeast1"
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.gmail_notifications.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.gmail_sync_download_function_source.email
  }

}

resource "google_cloud_run_service_iam_binding" "gmail_sync_download_invoker" {
  project  = google_cloudfunctions2_function.gmail_sync_download.project
  location = google_cloudfunctions2_function.gmail_sync_download.location
  service  = google_cloudfunctions2_function.gmail_sync_download.name
  role     = "roles/run.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_download_function_source.email}",
  ]
}

resource "google_cloudfunctions2_function_iam_binding" "gmail_sync_download_invoker" {
  project        = google_cloudfunctions2_function.gmail_sync_download.project
  location       = google_cloudfunctions2_function.gmail_sync_download.location
  cloud_function = google_cloudfunctions2_function.gmail_sync_download.name
  role           = "roles/cloudfunctions.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync_download_function_source.email}",
  ]
}
