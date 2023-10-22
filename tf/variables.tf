variable "gcp_project" {
  type = string
}

variable "gcp_region" {
  type = string
}

variable "gcp_zone" {
  type = string
}

variable "default_labels" {
  type    = map(string)
  default = {}
}

variable "network_name" {
  type    = string
  default = "main"
}

variable "network_ip_cidr_range" {
  type    = string
  default = "10.0.1.0/24"
}

variable "scheduler_timezone" {
  type    = string
  default = "UTC"
}

variable "gmail_sync_firestore_db" {
  type    = string
  default = "default"
}

variable "gmail_sync_firestore_collection" {
  type    = string
  default = "gmail_sync"
}

variable "gmail_sync_download_label_id" {
  type    = string
  default = "INBOX"
}

variable "gmail_sync_pubsub_topic" {
  type = string
}

variable "gmail_sync_renew_watch_schedule" {
  type    = string
  default = "0 0 * * *"
}

variable "gmail_sync_refresh_token_schedule" {
  type    = string
  default = "*/30 * * * *"

}

variable "gmail_sync_connect_client_secret_id" {
  type    = string
  default = "gmail-sync-client-secret"
}

variable "gmail_sync_service_account_secret_id" {
  type    = string
  default = "gmail-sync-sa-key"
}

variable "lakehouse_bucket_name" {
  type = string
}

variable "bookkeeping_bucket_name" {
  type = string
}
