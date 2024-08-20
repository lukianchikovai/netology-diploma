variable "yc_token" {
  description = "Yandex Cloud OAuth Token"
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
}
variable "yc_zone" {
  description = "List of Yandex Cloud Zones"
  type        = list(string)
  default     = ["ru-central1-a", "ru-central1-b"]
}
