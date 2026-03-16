resource "null_resource" "validate" {
  lifecycle {
    precondition {
      condition     = var.os_name != null || var.os_profile != null
      error_message = "Either os_name or os_profile must be provided"
    }

    precondition {
      condition = var.os_profile != null || var.os_image_mode == "url" || fileexists(local.selected_os.image)
      error_message = <<-EOT
        Image file not found: ${local.selected_os.image}
        [volume_name:${var.volume_name}, os_name:${coalesce(var.os_name, "none")}, image_mode:${var.os_image_mode}]

        Download it first:
          wget -O ${local.selected_os.image} ${local._builtin_os.image_url}

        Or switch to URL mode:
          image_mode = "url"
      EOT
    }
  }
}