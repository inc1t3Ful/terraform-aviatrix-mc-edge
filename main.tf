resource "aviatrix_edge_spoke" "default" {
  for_each = var.edge_gws

  #Required values
  gw_name                     = each.value.gw_name
  site_id                     = var.site_id
  management_interface_config = coalesce(each.value.management_interface_config, "DHCP")
  wan_interface_ip_prefix     = each.value.wan_interface_ip_prefix
  wan_default_gateway_ip      = each.value.wan_default_gateway_ip
  lan_interface_ip_prefix     = each.value.lan_interface_ip_prefix
  ztp_file_type               = var.ztp_file_type
  ztp_file_download_path      = local.ztp_file_download_path

  #Optional
  management_egress_ip_prefix            = each.value.management_egress_ip_prefix
  enable_management_over_private_network = each.value.enable_management_over_private_network
  enable_edge_active_standby             = each.value.enable_edge_active_standby
  enable_edge_active_standby_preemptive  = each.value.enable_edge_active_standby_preemptive
  management_interface_ip_prefix         = each.value.management_interface_ip_prefix
  management_default_gateway_ip          = each.value.management_default_gateway_ip
  dns_server_ip                          = each.value.dns_server_ip
  secondary_dns_server_ip                = each.value.secondary_dns_server_ip

  #Advanced options
  local_as_number                  = each.value.local_as_number
  prepend_as_path                  = each.value.prepend_as_path
  enable_learned_cidrs_approval    = each.value.enable_learned_cidrs_approval
  approved_learned_cidrs           = each.value.approved_learned_cidrs
  spoke_bgp_manual_advertise_cidrs = each.value.spoke_bgp_manual_advertise_cidrs
  enable_preserve_as_path          = each.value.enable_preserve_as_path
  bgp_polling_time                 = each.value.bgp_polling_time
  bgp_hold_time                    = each.value.bgp_hold_time
  enable_edge_transitive_routing   = each.value.enable_edge_transitive_routing
  enable_jumbo_frame               = each.value.enable_jumbo_frame
  latitude                         = each.value.latitude
  longitude                        = each.value.longitude
  wan_public_ip                    = each.value.wan_public_ip
}

resource "aviatrix_segmentation_network_domain_association" "default" {
  for_each = local.network_domain_attachments

  transit_gateway_name = each.value.transit
  network_domain_name  = var.network_domain
  attachment_name      = aviatrix_edge_spoke.default[each.value.gw_name].id

  lifecycle {
    precondition {
      condition     = aviatrix_edge_spoke.default[each.value.gw_name].state == "up"
      error_message = format("The edge gateway %s is not yet up. You can prevent this error by leaving it detached (do not set attached = true on each gateway) until the gateway is up.", each.value.gw_name)
    }
  }
}

resource "aviatrix_edge_spoke_transit_attachment" "default" {
  for_each = local.transit_attachments

  spoke_gw_name               = aviatrix_edge_spoke.default[each.value.gw_name].id
  transit_gw_name             = each.value.transit
  enable_jumbo_frame          = each.value.enable_jumbo_frame
  enable_over_private_network = each.value.enable_over_private_network
  enable_insane_mode          = each.value.enable_insane_mode
  insane_mode_tunnel_number   = each.value.insane_mode_tunnel_number
  spoke_prepend_as_path       = each.value.spoke_prepend_as_path
  transit_prepend_as_path     = each.value.transit_prepend_as_path

  lifecycle {
    precondition {
      condition     = aviatrix_edge_spoke.default[each.value.gw_name].state == "up"
      error_message = format("The edge gateway %s is not yet up. You can prevent this error by leaving it detached (do not set attached = true on each gateway) until the gateway is up.", each.value.gw_name)
    }
  }
}

resource "aviatrix_edge_spoke_external_device_conn" "default" {
  for_each = local.bgp_peers

  site_id           = var.site_id
  gw_name           = aviatrix_edge_spoke.default[each.value.gw_name].id
  connection_name   = each.value.connection_name
  bgp_local_as_num  = aviatrix_edge_spoke.default[each.value.gw_name].local_as_number
  bgp_remote_as_num = each.value.bgp_remote_as_num
  local_lan_ip      = split("/", aviatrix_edge_spoke.default[each.value.gw_name].lan_interface_ip_prefix)[0]
  remote_lan_ip     = each.value.remote_lan_ip
  connection_type   = "bgp" #Only supported value
  tunnel_protocol   = "LAN" #Only supported value

  lifecycle {
    precondition {
      condition     = can(signum(aviatrix_edge_spoke.default[each.value.gw_name].local_as_number))
      error_message = format("The edge gateway %s does not have a local as number configured. This is required for BGP peering.", each.value.gw_name)
    }

    precondition {
      condition     = aviatrix_edge_spoke.default[each.value.gw_name].state == "up"
      error_message = format("The edge gateway %s is not yet up. You can prevent this error by removing the BGP peerings until the gateway is up.", each.value.gw_name)
    }
  }
}
