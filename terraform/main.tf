# =====================================================================
# K8s-Sentry — minimal Azure AKS test environment.
#
# Provisions:
#   * A resource group
#   * An AKS cluster `aks-sentry-cluster` with one (system) node pool
#     and a system-assigned managed identity
#
# Kept intentionally small so it's cheap and quick for a lab. Run
# `terraform destroy` when you're finished. Cost note: the AKS control plane
# is free (Free tier); you pay for the node VMs and the load balancer.
# =====================================================================

locals {
  tags = {
    Project     = "k8s-sentry"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name

  # Empty string -> null -> AKS chooses the region's default version.
  kubernetes_version = var.kubernetes_version != "" ? var.kubernetes_version : null

  # SKU tier: Free is fine for a lab (no control-plane SLA). Use "Standard"
  # in production for the uptime SLA.
  sku_tier = "Free"

  default_node_pool {
    name            = "system"
    node_count      = var.node_count
    vm_size         = var.node_vm_size
    os_disk_size_gb = 30
    type            = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Cluster-managed identity (no service principal / secret to rotate).
  identity {
    type = "SystemAssigned"
  }

  # kubenet keeps the network simple and needs no pre-created subnet.
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  tags = local.tags
}
