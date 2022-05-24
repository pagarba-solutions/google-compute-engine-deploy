################################################################################
# Input variable definitions
################################################################################

variable "deployment_name" {
  description = "Name of the deployment."
  type        = string
}

variable "image_tag" {
  description = "full image gcr image tag"
  type        = string
}

variable "image_repository" {
  description = "gcr repository name"
  type        = string
}

variable "image_version" {
  description = "gcr image version"
  type        = string
}

variable "project_id" {
  description = "GCP project to use for creating deployment."
  type        = string
}

variable "zone" {
  description = "GCP project to use for creating deployment."
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "The machine type for compute engine."
  default     = "n1-standard-1"
}

################################################################################
# Resources
################################################################################

# Data source for container registry image
data "google_container_registry_image" "bento_service" {
  name    = var.image_repository
  project = var.project_id
}

module "gce-container" {
  # https://registry.terraform.io/modules/terraform-google-modules/container-vm/google/latest
  source         = "terraform-google-modules/container-vm/google"
  cos_image_name = "cos-stable-77-12371-89-0"
  container = {
    image = "${data.google_container_registry_image.bento_service.image_url}:${var.image_version}"
    env = [
      {
        name  = "BENTOML_PORT"
        value = "3000"
      },
    ]
  }

  restart_policy = "Always"
}

resource "google_compute_instance" "vm" {
  project                   = var.project_id
  name                      = "${var.deployment_name}-instance"
  machine_type              = "n1-standard-1"
  zone                      = "us-central1-a"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = module.gce-container.source_image
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    gce-container-declaration = module.gce-container.metadata_value
    google-logging-enabled    = "true"
    google-monitoring-enabled = "true"
  }

  labels = {
    container-vm = module.gce-container.vm_container_label
  }

  service_account {
    email = "558210432501-compute@developer.gserviceaccount.com"
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

resource "google_compute_firewall" "default" {
  name    = "bentoml-firewall"
  network = "default"
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

################################################################################
# Output value definitions
################################################################################

output "Endpoint" {
  description = "IP address for the instance"
  value = "http://${google_compute_instance.vm.network_interface.0.access_config.0.nat_ip}:3000"
}