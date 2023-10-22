resource "google_firestore_database" "default" {
  name                        = var.gmail_sync_firestore_db
  project                     = data.google_client_config.this.project
  location_id                 = data.google_client_config.this.region
  type                        = "FIRESTORE_NATIVE"
  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"
}

resource "google_storage_bucket" "lakehouse" {
  name                        = var.lakehouse_bucket_name
  location                    = data.google_client_config.this.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "bookkeeping" {
  name                        = var.bookkeeping_bucket_name
  location                    = data.google_client_config.this.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "gmail_sync_download_function_source" {
  name   = "function-source/gmail-sync-download.zip"
  bucket = google_storage_bucket.bookkeeping.name
  source = data.archive_file.gmail_sync_download_function_source.output_path
}

resource "google_storage_bucket_object" "gmail_sync_connect_function_source" {
  name   = "function-source/gmail-sync-connect.zip"
  bucket = google_storage_bucket.bookkeeping.name
  source = data.archive_file.gmail_sync_connect_source.output_path
}
