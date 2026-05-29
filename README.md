# marsa-charts

Helm charts for [Marsa](https://github.com/marsa-cloud/marsa) — a self-hostable, Heroku/Railway-style Platform-as-a-Service that deploys and manages applications on Kubernetes (K3s).

## What this repo is

This repository hosts the official Helm chart(s) for installing Marsa on a Kubernetes cluster. It is the operator's entry point to running Marsa — you `helm install` from here.

For Marsa itself (the application), see [`marsa-cloud/marsa`](https://github.com/marsa-cloud/marsa).

## Target platform

| Aspect | Value |
|--------|-------|
| Kubernetes distribution | **K3s** (Marsa is built and tested specifically for K3s) |
| Supported Kubernetes API version | **1.32** (the v0.1 target — see [chart-ci.yml](.github/workflows/chart-ci.yml)) |
| Ingress controller | **Traefik** (K3s's built-in default; no additional install required) |
| Storage class | **`local-path`** (K3s's built-in default; PVCs use the cluster default) |
| MVP deployment topology | **Server + agents on a local network** (no public-internet exposure assumed) |

Other Kubernetes distributions may work but are not validated. See the AgDR linked in the [Decisions](#decisions) section below for the rationale.

## Install

> **Status: coming with v0.1.0.** The first chart is not yet published. The install command below documents the planned UX.

```bash
helm install marsa oci://ghcr.io/marsa-cloud/charts/marsa --version 0.1.0
```

Requires **Helm 3.8+** (released March 2022) for native OCI registry support. There is no `helm repo add` step — charts are pulled directly from GitHub Container Registry.

## What's bundled

The v0.1 chart packages all of Marsa's required infrastructure so a single `helm install` produces a working system. No external services are required.

| Component | Version | How |
|-----------|---------|-----|
| Marsa application | `appVersion` from `Chart.yaml` | Templates in this repo |
| **Postgres** | `postgres:18.3-alpine` | Bundled — StatefulSet with PVC, init script creates the `marsa` database + user; generated passwords stored in a Kubernetes Secret and persisted across upgrades |
| **Redis** | `redis:7-alpine` | Bundled — Deployment with PVC for AOF persistence |
| **Ingress** | K3s built-in **Traefik** | Not bundled — the chart's `Ingress` resource uses Traefik's default ingressClassName |

## Out of scope (v0.1)

The v0.1 chart deliberately does **not** support these. They are deferred to a later version once real demand is established:

- **Bring-your-own (BYO) Postgres / Redis** — no `externalDatabase.host` / `*.enabled` values
- **Non-Traefik ingress controllers** — no ingressClassName customisation
- **cert-manager / public-internet TLS** — MVP assumes local-network deployment
- **High-availability / replication** — single replica per component
- **Multi-node / multi-AZ** — uses `local-path` storage class which is node-local
- **Public-internet-facing deployments** — not validated

See [AgDR-0004 in apexyard](https://github.com/marsa-cloud/apexyard/blob/main/projects/marsa-charts/docs/agdr/AgDR-0004-subchart-policy.md) for the full anti-scope rationale and revisit triggers.

## Versioning

This repo follows the [Helm community standard](https://helm.sh/docs/topics/charts/#charts-and-versioning) hybrid model:

- **`version`** (chart artifact) — independent SemVer per chart change
- **`appVersion`** (Marsa app release this chart packages) — tracks marsa releases

A chart-only fix (template typo, default value tweak) bumps `version` only. A new marsa release bumps `appVersion` + default image tags + the chart `version` accordingly.

See [AgDR-0002 in apexyard](https://github.com/marsa-cloud/apexyard/blob/main/projects/marsa-charts/docs/agdr/AgDR-0002-chart-versioning.md) for the policy details.

## Contributing

### Local development

```bash
# Lint a chart
helm lint charts/marsa

# chart-testing lint (validates against multiple Helm best-practices)
ct lint --target-branch main --chart-dirs charts

# Validate against a specific Kubernetes API version
helm template marsa charts/marsa | kubeconform -strict -kubernetes-version 1.32.0
```

### CI

Pull requests run [`chart-ci.yml`](.github/workflows/chart-ci.yml): `helm lint`, `ct lint`, `kubeconform` against k8s 1.32, plus a `gitleaks` secrets scan on every push. Chart-specific jobs skip cleanly until the first `Chart.yaml` lands under `charts/`.

PR titles must match the conventional commit format `type(#ISSUE): description` — enforced by [`pr-title-check.yml`](.github/workflows/pr-title-check.yml).

## Decisions

Architectural decisions for this repo are tracked as [Agent Decision Records (AgDRs)](https://github.com/marsa-cloud/apexyard/tree/main/projects/marsa-charts/docs/agdr) in the [`marsa-cloud/apexyard`](https://github.com/marsa-cloud/apexyard) ops repo. Current set:

| AgDR | Decision |
|------|----------|
| [0001](https://github.com/marsa-cloud/apexyard/blob/main/projects/marsa-charts/docs/agdr/AgDR-0001-chart-structure.md) | Single umbrella chart at `charts/marsa/` |
| [0002](https://github.com/marsa-cloud/apexyard/blob/main/projects/marsa-charts/docs/agdr/AgDR-0002-chart-versioning.md) | Chart `version` is independent SemVer; `appVersion` tracks marsa |
| [0003](https://github.com/marsa-cloud/apexyard/blob/main/projects/marsa-charts/docs/agdr/AgDR-0003-chart-distribution.md) | Publish as OCI artifacts to `ghcr.io/marsa-cloud/charts` |
| [0004](https://github.com/marsa-cloud/apexyard/blob/main/projects/marsa-charts/docs/agdr/AgDR-0004-subchart-policy.md) | v0.1 bundles Postgres + Redis, no BYO axis, K3s Traefik, no cert-manager |

## License

[AGPL-3.0](LICENSE) — the same license as the Marsa application. Self-hosting and modifying for your own use is fully permitted; offering Marsa as a hosted service to third parties triggers the AGPL's network-use clause.
