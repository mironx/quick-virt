variable "set_name" {
  description = "Name of the cluster for hosts file comments"
  type        = string
}

variable "file_name" {
  description = "Output file path for hosts file"
  type        = string
  default     = null
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