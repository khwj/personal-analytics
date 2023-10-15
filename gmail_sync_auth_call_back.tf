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
    #   SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
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

output "gmail_sync_auth_callback_url" {
  value = google_cloudfunctions2_function.gmail_sync_auth_callback.url
}
