# resource "null_resource" "validate_networks" {
#   count = length(keys(local.networks))
#
#   lifecycle {
#     precondition {
#       condition     = local.networks[keys(local.networks)[count.index]].mode == "nat" || local.networks[keys(local.networks)[count.index]].mode == "bridge"
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'mode' must be 'nat' or 'bridge'."
#     }
#
#
#     precondition {
#       condition     = local.networks[keys(local.networks)[count.index]].mode != "nat" || local.networks[keys(local.networks)[count.index]].domain != null
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'domain' must be set for 'nat' mode."
#     }
#
#     precondition {
#       condition     = local.networks[keys(local.networks)[count.index]].mode != "nat" || local.networks[keys(local.networks)[count.index]].mask != null
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'mask' must be set for 'nat' mode."
#     }
#
#     precondition {
#       condition     = !(local.networks[keys(local.networks)[count.index]].mode == "nat" && local.networks[keys(local.networks)[count.index]].dhcp_mode != "dhcp") || local.networks[keys(local.networks)[count.index]].gateway4 != null
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'gateway4' must be set for 'nat' with static IP."
#     }
#
#     precondition {
#       condition     = !(local.networks[keys(local.networks)[count.index]].mode == "nat" && local.networks[keys(local.networks)[count.index]].dhcp_mode != "dhcp") || length(local.networks[keys(local.networks)[count.index]].nameservers) > 0
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'nameservers' must be set for 'nat' with static IP."
#     }
#
#
#     precondition {
#       condition     = local.networks[keys(local.networks)[count.index]].mode != "bridge" || local.networks[keys(local.networks)[count.index]].bridge != null
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'bridge' must be set for 'bridge' mode."
#     }
#
#     precondition {
#       condition     = local.networks[keys(local.networks)[count.index]].mode != "bridge" || local.networks[keys(local.networks)[count.index]].mask != null
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'mask' must be set for 'bridge' mode."
#     }
#
#
#     precondition {
#       condition     = !(local.networks[keys(local.networks)[count.index]].mode == "bridge" && local.networks[keys(local.networks)[count.index]].dhcp_mode != "dhcp") || local.networks[keys(local.networks)[count.index]].gateway4 != null
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'gateway4' must be set for 'bridge' with static IP."
#     }
#
#     precondition {
#       condition     = !(local.networks[keys(local.networks)[count.index]].mode == "bridge" && local.networks[keys(local.networks)[count.index]].dhcp_mode != "dhcp") || length(local.networks[keys(local.networks)[count.index]].nameservers) > 0
#       error_message = "Network '${keys(local.networks)[count.index]}' error: 'nameservers' must be set for 'bridge' with static IP."
#     }
#   }
# }
