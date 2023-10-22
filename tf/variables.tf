variable "gcp_project" {
  type        = string
  description = "The Google Cloud Platform project ID."
}

variable "gcp_region" {
  type        = string
  description = "The default region for Google Cloud resources."
}

variable "gcp_zone" {
  type        = string
  description = "The default zone for Google Cloud resources."
}

variable "default_labels" {
  type        = map(string)
  default     = {}
  description = "A map of default labels to apply to all resources."
}

variable "network_name" {
  type        = string
  default     = "main"
  description = "The name of the Google Cloud VPC network."
}

variable "network_ip_cidr_range" {
  type        = string
  default     = "10.0.1.0/24"
  description = "The IP CIDR range for the subnetwork in the Google Cloud VPC network."
}

variable "scheduler_timezone" {
  type        = string
  default     = "UTC"
  description = "The timezone for the Cloud Scheduler jobs."
}

variable "gmail_sync_firestore_db" {
  type        = string
  default     = "default"
  description = "The Firestore database ID used by the Gmail Sync application."
}

variable "gmail_sync_firestore_collection" {
  type        = string
  default     = "gmail_sync"
  description = "The Firestore collection used by the Gmail Sync application."
}

variable "gmail_sync_download_label_id" {
  type        = string
  default     = "INBOX"
  description = "The Gmail label ID used to filter messages for download."
}

variable "gmail_sync_pubsub_topic_name" {
  type        = string
  description = "The Pub/Sub topic name for Gmail notifications."
}

variable "gmail_sync_pubsub_retention_duration" {
  type        = string
  default     = "606200s" # Default to 7 days
  description = "The duration to retain messages for the 'gmail_notifications' Pub/Sub topic. The value must be between 10 minutes and 7 days."
}

variable "gmail_sync_renew_watch_schedule" {
  type        = string
  default     = "0 0 * * *"
  description = "The schedule for the Cloud Scheduler job to renew the Gmail push notification watch."
}

variable "gmail_sync_refresh_token_schedule" {
  type        = string
  default     = "*/30 * * * *"
  description = "The schedule for the Cloud Scheduler job to refresh the Google OAuth access token."
}

variable "gmail_sync_connect_client_secret_id" {
  type        = string
  default     = "gmail-sync-client-secret"
  description = "The Secret Manager secret ID storing the Gmail Sync client secret."
}

variable "gmail_sync_service_account_secret_id" {
  type        = string
  default     = "gmail-sync-sa-key"
  description = "The Secret Manager secret ID storing the Gmail Sync service account key."
}

variable "lakehouse_bucket_name" {
  type        = string
  description = "The name of the Google Cloud Storage bucket for storing lakehouse data."
}

variable "attachment_save_path" {
  type        = string
  default     = "bronze"
  description = "The base path in the lakehouse bucket where attachments are saved."
}

variable "bookkeeping_bucket_name" {
  type        = string
  description = "The name of the Google Cloud Storage bucket for storing bookkeeping files."
}
