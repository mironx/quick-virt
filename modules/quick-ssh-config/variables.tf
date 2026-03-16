variable "set_name" {
  description = "Name of the cluster for SSH config comments"
  type        = string
}

variable "file_name" {
  description = "Output file path for SSH config"
  type        = string
  default     = null
}

variable "user" {
  description = "SSH user name"
  type        = string
}

variable "identity_file" {
  description = "Path to SSH identity file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "nodes" {
  description = "List of nodes with name and networks"
  type = list(object({
    name = string
    networks = optional(list(object({
      profile_name = string
      ip           = optional(string)
    })), [])
  }))
}