resource "google_pubsub_topic" "gmail_notifications" {
  name                       = var.gmail_sync_pubsub_topic_name
  message_retention_duration = var.gmail_sync_pubsub_retention_duration
}
