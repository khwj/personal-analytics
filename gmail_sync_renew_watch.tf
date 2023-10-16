resource "google_cloudfunctions2_function" "gmail_sync_renew_watch" {
  name     = "gmail-sync-renew-watch"
  location = data.google_client_config.this.region

  build_config {
    runtime     = "python311"
    entry_point = "renew_watch_handler"
    source {
      storage_source {
        bucket = google_storage_bucket.bookkeeping.name
        object = google_storage_bucket_object.gmail_sync_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    min_instance_count    = 0
    available_memory      = "256M"
    service_account_email = google_service_account.gmail_sync.email

    environment_variables = {
      FIRESTORE_COLLECTION           = "gmail_sync"
      FIRESTORE_DB                   = "default"
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = "google_credentials"
      GMAIL_NOTIFICATIONS_TOPIC      = "projects/khwunchai/topics/gmail_notifications"
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
}

resource "google_cloud_run_service_iam_binding" "gmail_sync_renew_watch_invoker" {
  project  = google_cloudfunctions2_function.gmail_sync_renew_watch.project
  location = google_cloudfunctions2_function.gmail_sync_renew_watch.location
  service  = google_cloudfunctions2_function.gmail_sync_renew_watch.name
  role     = "roles/run.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
    "serviceAccount:${google_service_account.scheduler.email}",
  ]
}

resource "google_cloudfunctions2_function_iam_binding" "gmail_sync_renew_watch_invoker" {
  project        = google_cloudfunctions2_function.gmail_sync_renew_watch.project
  location       = google_cloudfunctions2_function.gmail_sync_renew_watch.location
  cloud_function = google_cloudfunctions2_function.gmail_sync_renew_watch.name
  role           = "roles/cloudfunctions.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
    "serviceAccount:${google_service_account.scheduler.email}",
  ]
}

resource "google_cloud_scheduler_job" "invoke_gmail_sync_renew_watch" {
  name        = "invoke-gmail-sync-renew-watch"
  description = "Renew Gmail Push Notification subscription every 3 day"
  schedule    = "0 0 * * */3"
  project     = google_cloudfunctions2_function.gmail_sync_renew_watch.project
  region      = google_cloudfunctions2_function.gmail_sync_renew_watch.location
  time_zone   = "Asia/Bangkok"

  http_target {
    uri         = google_cloudfunctions2_function.gmail_sync_renew_watch.url
    http_method = "POST"
    oidc_token {
      audience              = "${google_cloudfunctions2_function.gmail_sync_renew_watch.service_config[0].uri}/"
      service_account_email = google_service_account.gmail_sync.email
    }
  }
}
