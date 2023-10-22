output "gmail_sync_auth_callback_url" {
  value = google_cloudfunctions2_function.gmail_sync_connect_callback.url
}

output "gmail_sync_connect_sa_key" {
  sensitive = true
  value     = google_service_account_key.gmail_sync_connect_sa_key.private_key
}