variable "set_name" {
  description = "Name of the cluster for SSH config comments"
  type        = string
}

variable "file_name" {
  description = "Output file path for SSH config"
  type        = string
  default     = null
}

variable "identity_file" {
  description = "Path to SSH identity file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "nodes" {
  description = "List of nodes with name, local_ip, and bridge_ip"
  type = list(object({
    name      = string
    local_ip  = optional(string)
    bridge_ip = optional(string)
  }))
}
