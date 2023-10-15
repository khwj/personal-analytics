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
  secret_data = google_service_account_key.gmail_sync_sa_key.private_key
}

resource "google_secret_manager_secret_iam_binding" "gmail_sync_client_secret_sa_binding" {
  project   = data.google_secret_manager_secret.gmail_sync_client_secret.project
  secret_id = data.google_secret_manager_secret.gmail_sync_client_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
  ]
}

resource "google_secret_manager_secret_iam_binding" "gmail_sync_sa_key_sa_binding" {
  project   = google_secret_manager_secret.gmail_sync_sa_key.project
  secret_id = google_secret_manager_secret.gmail_sync_sa_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
  ]
}

resource "google_cloudfunctions2_function" "gmail_sync_auth_callback" {
  name     = "gmail-sync-auth-callback"
  location = data.google_client_config.this.region

  build_config {
    runtime     = "python311"
    entry_point = "callback_handler"
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
    ingress_settings      = "ALLOW_ALL"
    service_account_email = google_service_account.gmail_sync.email

    environment_variables = {
      FIRESTORE_COLLECTION           = "gmail_sync"
      FIRESTORE_DB                   = "default"
      GOOGLE_CLIENT_SECRETS_FILE     = "/etc/secrets/client_secrets/${data.google_secret_manager_secret.gmail_sync_client_secret.secret_id}"
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GOOGLE_OAUTH_SCOPES            = "https://www.googleapis.com/auth/gmail.readonly"
      GMAIL_LABEL_ID                 = "Label_4739348339418472707"
      GMAIL_HISTORY_TYPES            = "messageAdded,labelAdded"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = "google_credentials"
      # google_auth_oauthlib still need this for some reason 
      GOOGLE_OAUTH_REDIRECT_URI = "https://${data.google_client_config.this.region}-${data.google_client_config.this.project}.cloudfunctions.net/gmail-sync-auth-callback"
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


resource "google_cloudfunctions2_function" "gmail_sync_refresh_token" {
  name     = "gmail-sync-refresh-token"
  location = data.google_client_config.this.region

  build_config {
    runtime     = "python311"
    entry_point = "refresh_token_handler"
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
    ingress_settings      = "ALLOW_ALL"
    service_account_email = google_service_account.gmail_sync.email

    environment_variables = {
      FIRESTORE_COLLECTION           = "gmail_sync"
      FIRESTORE_DB                   = "default"
      GOOGLE_CLIENT_SECRETS_FILE     = "/etc/secrets/client_secrets/${data.google_secret_manager_secret.gmail_sync_client_secret.secret_id}"
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GOOGLE_OAUTH_SCOPES            = "https://www.googleapis.com/auth/gmail.readonly"
      GMAIL_LABEL_ID                 = "Label_4739348339418472707"
      GMAIL_HISTORY_TYPES            = "messageAdded,labelAdded"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = "google_credentials"
      # google_auth_oauthlib still need this for some reason 
      GOOGLE_OAUTH_REDIRECT_URI = "https://${data.google_client_config.this.region}-${data.google_client_config.this.project}.cloudfunctions.net/gmail-sync-auth-callback"
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

resource "google_cloudfunctions2_function" "gmail_sync_renew_watch" {
  name     = "gmail-sync-renew-watch"
  location = data.google_client_config.this.region

  build_config {
    runtime     = "python311"
    entry_point = "renew_watch"
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
    ingress_settings      = "ALLOW_ALL"
    service_account_email = google_service_account.gmail_sync.email

    environment_variables = {
      FIRESTORE_COLLECTION           = "gmail_sync"
      FIRESTORE_DB                   = "default"
      GOOGLE_CLIENT_SECRETS_FILE     = "/etc/secrets/client_secrets/${data.google_secret_manager_secret.gmail_sync_client_secret.secret_id}"
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GOOGLE_OAUTH_SCOPES            = "https://www.googleapis.com/auth/gmail.readonly"
      GMAIL_LABEL_ID                 = "Label_4739348339418472707"
      GMAIL_HISTORY_TYPES            = "messageAdded,labelAdded"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = "google_credentials"
      GMAIL_NOTIFICATIONS_TOPIC      = "projects/khwunchai/topics/gmail_notifications"
      # google_auth_oauthlib still need this for some reason 
      GOOGLE_OAUTH_REDIRECT_URI = "https://${data.google_client_config.this.region}-${data.google_client_config.this.project}.cloudfunctions.net/gmail-sync-auth-callback"
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

resource "google_cloud_run_service_iam_binding" "gmail_sync_refresh_token_invoker" {
  project  = google_cloudfunctions2_function.gmail_sync_refresh_token.project
  location = google_cloudfunctions2_function.gmail_sync_refresh_token.location
  service  = google_cloudfunctions2_function.gmail_sync_refresh_token.name
  role     = "roles/run.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
    "serviceAccount:${google_service_account.scheduler.email}",
  ]
}

resource "google_cloudfunctions2_function_iam_binding" "gmail_sync_refresh_token_invoker" {
  project        = google_cloudfunctions2_function.gmail_sync_refresh_token.project
  location       = google_cloudfunctions2_function.gmail_sync_refresh_token.location
  cloud_function = google_cloudfunctions2_function.gmail_sync_refresh_token.name
  role           = "roles/cloudfunctions.invoker"

  members = [
    "serviceAccount:${google_service_account.gmail_sync.email}",
    "serviceAccount:${google_service_account.scheduler.email}",
  ]
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

resource "google_cloud_scheduler_job" "invoke_gmail_sync_refresh_token" {
  name        = "invoke-gmail-sync-refresh-token"
  description = "Refresh Google access token function every 20 minutes"
  schedule    = "*/20 * * * *"
  project     = google_cloudfunctions2_function.gmail_sync_refresh_token.project
  region      = google_cloudfunctions2_function.gmail_sync_refresh_token.location
  time_zone   = "Asia/Bangkok"

  http_target {
    uri         = google_cloudfunctions2_function.gmail_sync_refresh_token.url
    http_method = "POST"
    oidc_token {
      audience              = "${google_cloudfunctions2_function.gmail_sync_refresh_token.service_config[0].uri}/"
      service_account_email = google_service_account.gmail_sync.email
    }
  }
}

resource "google_cloud_scheduler_job" "invoke_gmail_sync_renew_watch" {
  name        = "invoke-gmail-sync-renew-watch"
  description = "Renew Gmail Push Notification subscription every 2 day"
  schedule    = "0 */2 * * *"
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

output "gmail_sync_auth_callback_url" {
  value = google_cloudfunctions2_function.gmail_sync_auth_callback.url
}

