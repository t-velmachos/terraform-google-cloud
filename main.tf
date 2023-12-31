# Copyright 2023 StreamNative, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "google_compute_zones" "available" {}

locals {

  ### Node Pools
  default_node_pool_config = {
    auto_repair        = var.node_pool_auto_repair
    auto_upgrade       = var.node_pool_auto_upgrade
    autoscaling        = var.node_pool_autoscaling
    disk_size_gb       = var.node_pool_disk_size
    disk_type          = var.node_pool_disk_type
    image_type         = var.node_pool_image_type
    initial_node_count = var.node_pool_autoscaling_initial_count
    local_ssd_count    = var.node_pool_ssd_count
    machine_type       = var.node_pool_machine_type
    max_count          = var.node_pool_autoscaling_max_size
    min_count          = var.node_pool_autoscaling_min_size
    name               = var.node_pool_name
    node_count         = var.node_pool_autoscaling ? null : var.node_pool_count
    node_locations     = var.node_pool_locations != "" ? var.node_pool_locations : ""
    service_account    = var.create_service_account ? "" : var.node_pool_service_account
    version            = var.node_pool_auto_upgrade ? null : var.node_pool_version
  }
  func_pool_config = {
    auto_repair        = var.func_pool_auto_repair
    auto_upgrade       = var.func_pool_auto_upgrade
    autoscaling        = var.func_pool_autoscaling
    disk_size_gb       = var.func_pool_disk_size
    disk_type          = var.func_pool_disk_type
    image_type         = var.func_pool_image_type
    initial_node_count = var.func_pool_autoscaling_initial_count
    local_ssd_count    = var.func_pool_ssd_count
    machine_type       = var.func_pool_machine_type
    max_count          = var.func_pool_autoscaling_max_size
    min_count          = var.func_pool_autoscaling_min_size
    name               = var.func_pool_name
    node_count         = var.func_pool_autoscaling ? null : var.func_pool_count
    node_locations     = var.func_pool_locations != "" ? var.func_pool_locations : var.node_pool_locations
    service_account    = var.create_service_account ? "" : var.func_pool_service_account
    version            = var.func_pool_auto_upgrade ? null : var.func_pool_version
  }
  node_pools = var.enable_func_pool ? [local.default_node_pool_config, local.func_pool_config] : [local.default_node_pool_config]
  node_pools_labels = {
    all = {
      cluster_name = var.cluster_name
      managed_by   = "terraform"
    }
  }
  node_pools_metadata = {
    all = {}
  }
  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    ]
  }

  node_pools_taints = {
    all = [
      for each in [
        {
          key    = "node.cilium.io/agent-not-ready"
          value  = true
          effect = "NO_EXECUTE"
        }
      ] : each if var.enable_cilium
    ]

    default-node-pool = [
      {
        key    = "default-node-pool"
        value  = true
        effect = "PREFER_NO_SCHEDULE"
      },
    ]

    func-pool = [
      {
        key    = "func-pool"
        value  = true
        effect = "PREFER_NO_SCHEDULE"
      },
    ]
  }
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  name    = var.cluster_name
  version = "19.0.0"

  add_cluster_firewall_rules        = var.add_cluster_firewall_rules
  add_master_webhook_firewall_rules = var.add_master_webhook_firewall_rules
  add_shadow_firewall_rules         = var.add_shadow_firewall_rules
  cluster_autoscaling               = var.cluster_autoscaling_config
  http_load_balancing               = var.cluster_http_load_balancing
  ip_range_pods                     = var.secondary_ip_range_pods
  ip_range_services                 = var.secondary_ip_range_services
  kubernetes_version                = var.kubernetes_version
  logging_service                   = var.logging_service
  maintenance_exclusions            = var.maintenance_exclusions
  maintenance_start_time            = var.maintenance_window
  master_authorized_networks        = var.master_authorized_networks
  network                           = var.vpc_network
  network_project_id                = var.network_project_id
  network_policy                    = var.cluster_network_policy
  node_pools                        = local.node_pools
  node_pools_labels                 = local.node_pools_labels
  node_pools_metadata               = local.node_pools_metadata
  node_pools_oauth_scopes           = local.node_pools_oauth_scopes
  node_pools_taints                 = local.node_pools_taints
  project_id                        = var.project_id
  region                            = var.region
  remove_default_node_pool          = true
  release_channel                   = var.release_channel
  subnetwork                        = var.vpc_subnet
}

resource "kubernetes_namespace" "sn_system" {
  metadata {
    name = "sn-system"

    labels = {
      "istio.io/rev"               = "sn-stable"
      "cloud.streamnative.io/role" = "sn-system"
    }
  }
  depends_on = [
    module.gke
  ]
}

resource "kubernetes_storage_class" "sn_default" {
  metadata {
    name = "sn-default"
    labels = {
      "addonmanager.kubernetes.io/mode" = "EnsureExists"
    }
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  parameters = {
    type = "pd-standard"
  }
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  depends_on = [
    module.gke
  ]
}

resource "kubernetes_storage_class" "sn_ssd" {
  metadata {
    name = "sn-ssd"
    labels = {
      "addonmanager.kubernetes.io/mode" = "EnsureExists"
    }
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  parameters = {
    type = "pd-ssd"
  }
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  depends_on = [
    module.gke
  ]
}
