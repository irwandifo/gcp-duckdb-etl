terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.12.0"
    }
  }
}

# Create a ZIP archive of the function
data "archive_file" "default" {
  type        = "zip"
  output_path = "tmp/function-source.zip"
  source_dir  = "../function"
}

# Upload the ZIP file to GCS
resource "google_storage_bucket_object" "object" {
  name   = "${var.function_name}/function-source.zip"
  bucket = var.bucket_name
  source = data.archive_file.default.output_path
}

resource "google_cloudfunctions2_function" "function" {
  name        = var.function_name
  project     = var.project_id
  location    = var.location

  build_config {
    runtime         = var.runtime
    entry_point     = var.entry_point
    service_account = "projects/${var.project_id}/serviceAccounts/${var.service_account}"
    source {
      storage_source {
        bucket = var.bucket_name
        object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    min_instance_count               = var.min_instance
    max_instance_count               = var.max_instance
    max_instance_request_concurrency = var.max_concurrency
    available_memory                 = var.memory
    available_cpu                    = var.cpu
    timeout_seconds                  = 60
    service_account_email            = var.service_account
  }
}

resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = google_cloudfunctions2_function.function.project
  location       = google_cloudfunctions2_function.function.location
  cloud_function = google_cloudfunctions2_function.function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${var.service_account}"
}

resource "google_cloud_run_service_iam_member" "cloud_run_invoker" {
  project  = google_cloudfunctions2_function.function.project
  location = google_cloudfunctions2_function.function.location
  service  = google_cloudfunctions2_function.function.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.service_account}"
}

resource "google_cloud_scheduler_job" "invoke_cloud_function" {
  name        = var.scheduler_name
  schedule    = var.schedule
  time_zone   = var.timezone
  project     = google_cloudfunctions2_function.function.project
  region      = google_cloudfunctions2_function.function.location

  http_target {
    uri         = google_cloudfunctions2_function.function.service_config[0].uri
    http_method = "POST"
    headers     = {
      "Content-Type" = "application/json",
      "User-Agent"   = "Google-Cloud-Scheduler"
    }
    body        = base64encode(var.http_body)
    oidc_token {
      audience              = "${google_cloudfunctions2_function.function.service_config[0].uri}/"
      service_account_email = var.service_account
    }
  }
}
