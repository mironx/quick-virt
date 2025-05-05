variable "vm_profile" {
  type = object({
    vcpu      = number
    memory    = number,
    cpu = optional(object({
      mode = optional(string)
    }))
  })
  description = "VM profile configuration."
}

variable "user" {
  type = object({
    name     = string
    password = string
  })
  description = "User profile configuration."
}