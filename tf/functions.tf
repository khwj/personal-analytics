locals {
  google_credentials_document_id = "google_credentials"
  gmail_sync_state_document_id   = "last_sync_state"
}
resource "google_cloudfunctions2_function" "gmail_sync_connect_callback" {
  name     = "gmail-sync-connect-callback"
  location = data.google_client_config.this.region

  build_config {
    runtime     = "python311"
    entry_point = "callback_handler"
    source {
      storage_source {
        bucket = google_storage_bucket.bookkeeping.name
        object = google_storage_bucket_object.gmail_sync_connect_function_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    min_instance_count = 0
    available_memory   = "256M"
    # Need to handle redirection from Google OAuth
    ingress_settings      = "ALLOW_ALL"
    service_account_email = google_service_account.gmail_sync_connect.email

    environment_variables = {
      FIRESTORE_COLLECTION           = var.gmail_sync_firestore_collection
      FIRESTORE_DB                   = var.gmail_sync_firestore_db
      GOOGLE_CLIENT_SECRETS_FILE     = "/etc/secrets/client_secrets/${data.google_secret_manager_secret.gmail_sync_connect_client_secret.secret_id}"
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GOOGLE_OAUTH_SCOPES            = "https://www.googleapis.com/auth/gmail.readonly"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = local.google_credentials_document_id
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
      project_id = data.google_secret_manager_secret.gmail_sync_connect_client_secret.project
      secret     = data.google_secret_manager_secret.gmail_sync_connect_client_secret.secret_id
    }
  }
}

resource "google_cloudfunctions2_function" "gmail_sync_connect_refresh_token" {
  name     = "gmail-sync-connect-refresh-token"
  location = data.google_client_config.this.region

  build_config {
    runtime     = "python311"
    entry_point = "refresh_token_handler"
    source {
      storage_source {
        bucket = google_storage_bucket.bookkeeping.name
        object = google_storage_bucket_object.gmail_sync_connect_function_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    min_instance_count    = 0
    available_memory      = "256M"
    service_account_email = google_service_account.gmail_sync_connect.email

    environment_variables = {
      FIRESTORE_COLLECTION           = var.gmail_sync_firestore_collection
      FIRESTORE_DB                   = var.gmail_sync_firestore_db
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = local.google_credentials_document_id
    }

    secret_volumes {
      mount_path = "/etc/secrets/sa_keys"
      project_id = google_secret_manager_secret.gmail_sync_sa_key.project
      secret     = google_secret_manager_secret.gmail_sync_sa_key.secret_id
    }

    secret_volumes {
      mount_path = "/etc/secrets/client_secrets"
      project_id = data.google_secret_manager_secret.gmail_sync_connect_client_secret.project
      secret     = data.google_secret_manager_secret.gmail_sync_connect_client_secret.secret_id
    }
  }
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
    service_account_email = google_service_account.gmail_sync_download_function.email

    environment_variables = {
      FIRESTORE_COLLECTION           = var.gmail_sync_firestore_collection
      FIRESTORE_DB                   = var.gmail_sync_firestore_db
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GMAIL_LABEL_ID                 = var.gmail_sync_download_label_id
      GMAIL_HISTORY_TYPES            = "messageAdded,labelAdded"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = local.google_credentials_document_id

      DESTINATION_BUCKET_NAME = google_storage_bucket.lakehouse.name
      DESTINATION_BASE_PATH   = var.attachment_save_path
      SYNC_STATE_DOCUMENT_ID  = local.gmail_sync_state_document_id
    }

    secret_volumes {
      mount_path = "/etc/secrets/sa_keys"
      project_id = google_secret_manager_secret.gmail_sync_sa_key.project
      secret     = google_secret_manager_secret.gmail_sync_sa_key.secret_id
    }

    secret_volumes {
      mount_path = "/etc/secrets/client_secrets"
      project_id = data.google_secret_manager_secret.gmail_sync_connect_client_secret.project
      secret     = data.google_secret_manager_secret.gmail_sync_connect_client_secret.secret_id
    }
  }

  event_trigger {
    trigger_region        = data.google_client_config.this.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.gmail_notifications.id
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.gmail_sync_download_function.email
  }

}

resource "google_cloudfunctions2_function" "gmail_sync_renew_watch" {
  name     = "gmail-sync-renew-watch"
  location = data.google_client_config.this.region

  build_config {
    runtime     = "python311"
    entry_point = "renew_watch_handler"
    source {
      storage_source {
        bucket = google_storage_bucket.bookkeeping.name
        object = google_storage_bucket_object.gmail_sync_connect_function_source.name
      }
    }
  }

  service_config {
    max_instance_count    = 1
    min_instance_count    = 0
    available_memory      = "256M"
    service_account_email = google_service_account.gmail_sync_connect.email

    environment_variables = {
      FIRESTORE_COLLECTION           = var.gmail_sync_firestore_collection
      FIRESTORE_DB                   = var.gmail_sync_firestore_db
      SERVICE_ACCOUNT_KEY_FILE       = "/etc/secrets/sa_keys/${google_secret_manager_secret.gmail_sync_sa_key.secret_id}"
      GOOGLE_CREDENTIALS_DOCUMENT_ID = local.google_credentials_document_id
      GMAIL_NOTIFICATIONS_TOPIC      = google_pubsub_topic.gmail_notifications.id
    }

    secret_volumes {
      mount_path = "/etc/secrets/sa_keys"
      project_id = google_secret_manager_secret.gmail_sync_sa_key.project
      secret     = google_secret_manager_secret.gmail_sync_sa_key.secret_id
    }

    secret_volumes {
      mount_path = "/etc/secrets/client_secrets"
      project_id = data.google_secret_manager_secret.gmail_sync_connect_client_secret.project
      secret     = data.google_secret_manager_secret.gmail_sync_connect_client_secret.secret_id
    }
  }
}
