data "google_client_config" "this" {
}

data "archive_file" "gmail_sync_connect_source" {
  type       = "zip"
  source_dir = "../gmail_sync/"
  excludes = [
    "__pycache__",
    ".pytest_cache",
    ".vscode",
    ".coveragerc",
    "requirements.test.txt",
    "tests",
    "venv",
  ]
  output_path = "/tmp/gmail_sync_connect.zip"
}

data "archive_file" "gmail_sync_download_function_source" {
  type       = "zip"
  source_dir = "../gmail_sync/"
  excludes = [
    "__pycache__",
    ".pytest_cache",
    ".vscode",
    ".coveragerc",
    "requirements.test.txt",
    "tests",
    "venv",
  ]
  output_path = "/tmp/gmail_sync_download.zip"
}

data "google_secret_manager_secret" "gmail_sync_connect_client_secret" {
  secret_id = var.gmail_sync_connect_client_secret_id
}
