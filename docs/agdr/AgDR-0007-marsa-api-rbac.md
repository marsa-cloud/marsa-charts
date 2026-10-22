# marsa-api RBAC: dedicated ServiceAccount + broad namespace-scoped Role

> In the context of the marsa-api operator deploying tenant apps into the `marsa-apps` namespace, facing a `403 Forbidden` because the pod runs as the namespace `default` ServiceAccount with no RBAC, I decided to give it a dedicated `marsa-api` ServiceAccount bound to a **broad but namespace-scoped** Role in `marsa-apps`, to achieve working deploys with room to grow the operator's capabilities, accepting that the Role grants more than the exact call set the code uses today.

## Context

`apps/api/src/modules/kubernetes/direct-apply-deploy-backend.ts` (`DirectApplyDeployBackend.apply`) server-side-applies a Deployment, Service, image-pull Secret, and a Traefik `IngressRoute` into `OPERATOR_APPS_NAMESPACE` (`marsa-apps`), and reads back Deployments, Pods, and Pod logs. The marsa-api pod authenticates to the K3s API as whatever ServiceAccount its Deployment declares. The chart's `deployment.yml` set none, so the pod ran as `system:serviceaccount:marsa:default` — a SA with no RoleBinding anywhere. Every deploy failed on the first write (`patch deployments` → 403).

The chart shipped **no** RBAC objects at all (no ServiceAccount, Role, RoleBinding, or ClusterRole). The `marsa-apps` namespace is a different namespace from the chart's own release namespace (`marsa`), so cross-namespace RBAC is required: a Role/RoleBinding living in `marsa-apps`, with the SA (in the release namespace) as the subject.

The CEO directed that marsa-api be given **wider** permissions than the strict minimum — the operator will grow (scale, rollback, delete, jobs, HPA, PVCs) and re-cutting RBAC + a chart release on every new capability is unwanted friction.

## Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **A. Minimal least-privilege Role** — only the exact verbs/resources the code touches today (deployments/services/secrets patch+get, pods get/list, pods/log get, ingressroutes patch+get) | Tightest blast radius; textbook least-privilege | Every new operator capability needs an RBAC change + chart release; high friction; explicitly rejected by CEO |
| **B. Broad namespace-scoped Role** — full verbs on the common workload/config/networking groups + Traefik CRDs, scoped to `marsa-apps` via a `Role` | Room to grow with zero RBAC churn; blast radius bounded to the tenant-apps namespace the operator already owns; still a `Role`, not cluster-wide | Grants more than needed today; SA can do anything to resources in `marsa-apps` |
| **C. ClusterRole / cluster-admin** — bind the SA cluster-wide | Never touch RBAC again for any namespace | Unacceptable blast radius — an API compromise = whole-cluster compromise; violates namespace isolation the PaaS relies on |
| **D. Reuse the `default` SA, just add a binding** | No new SA object | `default` SA is shared by every pod in the namespace and is un-auditable; anti-pattern; a leaked `default` token grants the operator's rights |

## Decision

Chosen: **Option B (broad, namespace-scoped Role) with a dedicated `marsa-api` ServiceAccount (from Option D's rejection)**, because it satisfies the CEO's "wider permissions" direction while keeping the security boundary that actually matters — the Role is namespaced to `marsa-apps`, so even full CRUD there cannot touch the control-plane namespace (`marsa`), other tenants' cluster scope, or cluster-scoped resources. A dedicated SA (not `default`) makes the operator's identity auditable and its token blast-radius its own.

Concretely:

- **ServiceAccount** `marsa-api` in the release namespace; `serviceAccountName: marsa-api` wired onto the `marsa-api` Deployment.
- **Role** `marsa-deployer` in `marsa-apps`:
  - `apiGroups: ["", "apps", "batch", "autoscaling", "networking.k8s.io", "policy"]`, `resources: ["*"]`, `verbs: ["*"]`
  - `apiGroups: ["traefik.io"]`, `resources: ["*"]`, `verbs: ["*"]`
- **RoleBinding** `marsa-deployer` in `marsa-apps`, subject = ServiceAccount `marsa-api` in the release namespace.
- **Namespace** `marsa-apps` templated by the chart (helm creates namespaces before RBAC in its install order) so a fresh install is self-contained.
- Deliberately **excludes** `rbac.authorization.k8s.io` from the granted groups, so the SA cannot escalate its own privileges by editing Roles/RoleBindings even within `marsa-apps`.

## Consequences

- Deploys succeed: marsa-api can create/patch/read every resource `apply()` and the read paths touch, plus future ones (jobs, HPAs, PVCs, statefulsets) without an RBAC change.
- Blast radius of a marsa-api compromise is bounded to the `marsa-apps` namespace; the control-plane namespace and cluster scope stay out of reach, and self-escalation via RBAC edits is blocked.
- **Coupling to code:** the chart's `appsNamespace` value (default `marsa-apps`) must equal the API's hardcoded `OPERATOR_APPS_NAMESPACE`. If V0.2 introduces project×environment namespacing (per marsa AgDR-0030), this single-namespace Role must be revisited (per-namespace RBAC or a controller-managed grant).
- Trade-off accepted: the Role is broader than strict least-privilege. Revisit toward Option A's tightness if a future audit requires it; the namespace scope is the compensating control until then.

## Artifacts

- marsa-cloud/marsa-charts#22
- PR: (to be linked)
- Root cause: 403 on `patchNamespacedDeployment` in `DirectApplyDeployBackend.apply` (`apps/api/src/modules/kubernetes/direct-apply-deploy-backend.ts`)
