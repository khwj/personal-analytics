resource "google_pubsub_topic" "gmail_notifications" {
  name                       = "gmail_notifications"
  message_retention_duration = "606200s" # 7 days
  # message_retention_duration = "86600s" # 1 day
}
