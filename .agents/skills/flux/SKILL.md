---
name: flux
description: >-
  Analyze and troubleshoot the Flux GitOps pipeline via the flux-operator-mcp tools.
  Reach for this on any Flux/GitOps task: "why isn't <app> syncing/reconciling", a
  HelmRelease or Kustomization stuck/failed/not-ready, checking the FluxInstance or Flux
  controllers, inspecting a Flux resource's spec/status/events/inventory, or
  creating/applying Flux-managed resources. Covers FluxInstance, HelmRelease,
  Kustomization, GitRepository/OCIRepository, HelmRepository/HelmChart, ResourceSet, and
  the source/kustomize/helm controllers.
---

# Flux MCP — GitOps troubleshooting

You analyze and troubleshoot GitOps pipelines managed by Flux Operator on Kubernetes
clusters, using the `flux-operator-mcp` tools to connect to clusters and fetch
Kubernetes and Flux resources.

## Flux Custom Resources Overview

Flux consists of the following Kubernetes controllers and custom resource definitions (CRDs):

- Flux Operator
  - **FluxInstance**: Manages the Flux controllers installation and configuration
  - **FluxReport**: Reflects the state of a Flux installation
  - **ResourceSet**: Manages groups of Kubernetes resources based on input matrices
  - **ResourceSetInputProvider**: Fetches input values from external services (GitHub, GitLab)
- Source Controller
  - **GitRepository**: Points to a Git repository containing Kubernetes manifests or Helm charts
  - **OCIRepository**: Points to a container registry containing OCI artifacts (manifests or Helm charts)
  - **Bucket**: Points to an S3-compatible bucket containing manifests
  - **HelmRepository**: Points to a Helm chart repository
  - **HelmChart**: References a chart from a HelmRepository or a GitRepository
- Kustomize Controller
  - **Kustomization**: Builds and applies Kubernetes manifests from sources
- Helm Controller
  - **HelmRelease**: Manages Helm chart releases from sources
- Notification Controller
  - **Provider**: Represents a notification service (Slack, MS Teams, etc.)
  - **Alert**: Configures events to be forwarded to providers
  - **Receiver**: Defines webhooks for triggering reconciliations
- Image Automation Controllers
  - **ImageRepository**: Scans container registries for new tags
  - **ImagePolicy**: Selects the latest image tag based on policy
  - **ImageUpdateAutomation**: Updates Git repository with new image tags

For Flux API guidance, call the `search_flux_docs` tool with targeted questions. Use the default concise format for normal troubleshooting and manifest guidance, and request `format: complete` only when the full upstream API documentation is needed.

## General rules

- When asked about the Flux installation status, call the `get_flux_instance` tool.
- When asked about Kubernetes or Flux resources, call the `get_kubernetes_resources` tool.
- Don't make assumptions about the `apiVersion` of a Kubernetes or Flux resource, call the `get_kubernetes_api_versions` tool to find the correct one.
- To determine if a Kubernetes resource is Flux-managed, search the metadata field for `fluxcd` labels.
- When asked to create or update resources, generate a Kubernetes YAML manifest and call the `apply_kubernetes_resource` tool to apply it.
- Avoid applying changes to Flux-managed resources unless explicitly requested.
- When asked about Flux CRDs, call the `search_flux_docs` tool with a targeted query. Prefer the default concise format; use `format: complete` only when the full upstream API docs are needed.

## Kubernetes logs analysis

When looking at logs, first you need to determine the pod name:

- Get the Kubernetes deployment that manages the pods using the `get_kubernetes_resources` tool.
- Look for the `matchLabels` and the container name in the deployment spec.
- List the pods with the `get_kubernetes_resources` tool using the found `matchLabels` from the deployment spec.
- Get the logs by calling the `get_kubernetes_logs` tool using the pod name and container name.

## Flux resource analysis

Troubleshooting a HelmRelease and a Kustomization is the same flow — only the controller
and the field names differ:

| kind | controller | source field | referenced values |
|---|---|---|---|
| HelmRelease | helm-controller | `chartRef` / `sourceRef` | `valuesFrom` |
| Kustomization | kustomize-controller | `sourceRef` | `substituteFrom` |

Steps:

- Use the `get_flux_instance` tool to check the controller's deployment status and the apiVersion of the kind.
- Use the `get_kubernetes_resources` tool to get the resource, then analyze the spec, the status, inventory and events.
- Determine which Flux object is managing it by looking at the annotations; it can be a Kustomization or a ResourceSet.
- If the referenced-values field is present, get all the referenced ConfigMap and Secret resources.
- Identify the source by looking at the source field, then use `get_kubernetes_resources` to get it and analyze its status and events.
- If the resource is in a failed state or in progress, it may be due to failures in one of the managed resources found in the inventory. Use `get_kubernetes_resources` to get them and analyze their status.
- If the managed resources are in a failed state, analyze their logs using the `get_kubernetes_logs` tool.
- If any issues were found, create a root cause analysis report for the user.
- If no issues were found, create a report with the current status of the resource, its managed resources, and their container images.
