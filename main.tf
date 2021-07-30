#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  name    = var.cluster_name
  version = "16.0.1"

  add_cluster_firewall_rules        = var.add_cluster_firewall_rules
  add_master_webhook_firewall_rules = var.add_master_webhook_firewall_rules
  add_shadow_firewall_rules         = var.add_shadow_firewall_rules
  cluster_autoscaling               = var.cluster_autoscaling_config
  http_load_balancing               = var.cluster_http_load_balancing
  ip_range_pods                     = var.create_cluster_subnet ? google_compute_subnetwork.cluster_subnet[0].secondary_ip_range[0].range_name : null
  ip_range_services                 = var.create_cluster_subnet ? google_compute_subnetwork.cluster_subnet[0].secondary_ip_range[1].range_name : null
  kubernetes_version                = var.kubernetes_version
  logging_service                   = var.logging_service
  maintenance_exclusions            = var.maintenance_exclusions
  maintenance_start_time            = var.maintenance_window
  network                           = var.vpc_network
  network_policy                    = var.cluster_network_policy
  node_pools                        = local.node_pools
  node_pools_labels                 = local.node_pools_labels
  node_pools_metadata               = local.node_pools_metadata
  node_pools_oauth_scopes           = local.node_pools_oauth_scopes
  node_pools_taints                 = local.node_pools_taints
  project_id                        = var.project_id
  region                            = var.cluster_location
  remove_default_node_pool          = var.remove_default_node_pool
  release_channel                   = var.release_channel
  subnetwork                        = var.create_cluster_subnet ? google_compute_subnetwork.cluster_subnet[0].name : var.vpc_subnet
}

resource "kubernetes_namespace" "sn_system" {
  metadata {
    name = "sn-system"
  }
  depends_on = [
    module.gke
  ]
}

resource "kubernetes_namespace" "pulsar" {
  count = var.manage_pulsar_namespace ? 1 : 0
  metadata {
    name = var.pulsar_namespace
  }
  depends_on = [
    module.gke
  ]
}

resource "kubernetes_namespace" "istio" {
  count = var.enable_istio_operator ? 1 : 0
  metadata {
    name = "istio-system"
  }
  depends_on = [
    module.gke
  ]
}