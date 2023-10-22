resource "google_cloud_scheduler_job" "invoke_gmail_sync_refresh_token" {
  name        = "invoke-gmail-sync-refresh-token"
  description = "Refresh Google access token function"
  schedule    = var.gmail_sync_refresh_token_schedule
  project     = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.project
  region      = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.location
  time_zone   = var.scheduler_timezone

  http_target {
    uri         = google_cloudfunctions2_function.gmail_sync_connect_refresh_token.url
    http_method = "POST"
    oidc_token {
      audience              = "${google_cloudfunctions2_function.gmail_sync_connect_refresh_token.service_config[0].uri}/"
      service_account_email = google_service_account.gmail_sync_connect.email
    }
  }
}

resource "google_cloud_scheduler_job" "invoke_gmail_sync_renew_watch" {
  name        = "invoke-gmail-sync-renew-watch"
  description = "Renew Gmail Push Notification subscription"
  schedule    = var.gmail_sync_renew_watch_schedule
  project     = google_cloudfunctions2_function.gmail_sync_renew_watch.project
  region      = google_cloudfunctions2_function.gmail_sync_renew_watch.location
  time_zone   = var.scheduler_timezone

  http_target {
    uri         = google_cloudfunctions2_function.gmail_sync_renew_watch.url
    http_method = "POST"
    oidc_token {
      audience              = "${google_cloudfunctions2_function.gmail_sync_renew_watch.service_config[0].uri}/"
      service_account_email = google_service_account.gmail_sync_connect.email
    }
  }
}
