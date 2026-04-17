# DevSecOps Security Pipeline Architecture
> Senior DevOps Architect | Production-Grade | LinkedIn Content Series

---

## 1. Architecture Title

**"Shift Left or Get Breached: DevSecOps Pipeline Architecture — Security at Every Layer from Code to Cloud"**

---

## 2. Problem Statement

**The Real-World Engineering Problem:**

Security is traditionally the last gate before production — a manual review after everything is built. In a world where teams ship daily, this model fails completely:

- A vulnerable Docker base image gets deployed to production because no one scanned it
- A hardcoded AWS secret gets committed, scraped by bots within 3 minutes, S3 buckets exfiltrated
- A container runs as `root` because the Dockerfile was copy-pasted from a tutorial
- A Log4Shell-equivalent zero-day sits in a transitive dependency nobody audited

**The cost is catastrophic:** The average data breach costs $4.45M (IBM 2023). 80% of breaches involve credentials. 60% of vulnerabilities are known and patchable at the time of exploitation.

**DevSecOps solves this by making security a first-class citizen at every pipeline stage:**
- Developer commit → secret scanning
- Build → dependency vulnerability scan
- Docker image → container image scan
- Kubernetes manifest → policy enforcement
- Runtime → behavioral anomaly detection

Security shifts left. Every layer has a gate. Nothing reaches production unscan.

---

## 3. Tools and Technologies Used

| Category | Tool |
|---|---|
| **Secret Scanning** | GitLeaks / GitHub Secret Scanning / TruffleHog |
| **SAST (Static Analysis)** | SonarQube / Semgrep / Bandit (Python) |
| **Dependency Scanning** | Snyk / OWASP Dependency Check / Trivy |
| **Container Image Scanning** | Trivy / Grype / Clair / Docker Scout |
| **IaC Security** | Checkov / tfsec / KICS |
| **Policy Enforcement (K8s)** | OPA Gatekeeper / Kyverno |
| **Runtime Security** | Falco |
| **Network Policy** | Kubernetes NetworkPolicy / Cilium |
| **Secret Management** | HashiCorp Vault / AWS Secrets Manager / ESO |
| **SBOM Generation** | Syft / CycloneDX |
| **Compliance** | OpenSCAP / Drata / Vanta |
| **CI/CD** | GitHub Actions / GitLab CI |
| **Container Registry** | Docker Hub / ECR (with scan-on-push) |
| **Alerting** | PagerDuty / Slack / Falco Sidekick |

---

## 4. Architecture Diagram Flow

```
  ┌───────────────────────────────────────────────────────────────┐
  │  PHASE 1: PRE-COMMIT (Developer Machine)                      │
  │                                                               │
  │  git commit →  pre-commit hooks fire                          │
  │                ├── GitLeaks: scan for secrets/keys            │
  │                ├── Bandit/Semgrep: SAST on changed files      │
  │                └── Commit blocked if HIGH severity found      │
  └──────────────────────────────┬────────────────────────────────┘
                                 ↓ push to GitHub
  ┌───────────────────────────────────────────────────────────────┐
  │  PHASE 2: CI PIPELINE — Code & Dependency Security           │
  │                                                               │
  │  GitHub Actions triggers on PR/push                          │
  │  ├── Secret Scanning (GitHub Advanced Security / TruffleHog) │
  │  ├── SAST Scan (SonarQube / Semgrep)                         │
  │  ├── Dependency Scan (Snyk / Trivy filesystem mode)           │
  │  ├── License Compliance Check                                 │
  │  └── GATE: fail pipeline on CRITICAL / HIGH CVEs             │
  └──────────────────────────────┬────────────────────────────────┘
                                 ↓ tests + scans pass
  ┌───────────────────────────────────────────────────────────────┐
  │  PHASE 3: CONTAINER BUILD & IMAGE SECURITY                    │
  │                                                               │
  │  Docker Build                                                 │
  │  ├── Base image: distroless / alpine (minimal attack surface) │
  │  ├── Run as non-root user (USER 1000)                         │
  │  ├── Read-only filesystem                                     │
  │  ├── No secrets in layers (multi-stage build)                 │
  │  ↓                                                            │
  │  Image Scan: Trivy / Grype                                    │
  │  ├── Scan OS packages (CVEs)                                  │
  │  ├── Scan language dependencies                               │
  │  ├── Generate SBOM (Software Bill of Materials)               │
  │  └── GATE: block push on CRITICAL CVEs                        │
  └──────────────────────────────┬────────────────────────────────┘
                                 ↓ image approved
  ┌───────────────────────────────────────────────────────────────┐
  │  PHASE 4: IMAGE SIGNING & REGISTRY                            │
  │                                                               │
  │  Cosign signs image (keyless signing via OIDC)                │
  │  Push to ECR / Docker Hub (with signed digest)                │
  │  SBOM attached to image in registry                           │
  │  Registry: scan-on-push enabled                               │
  └──────────────────────────────┬────────────────────────────────┘
                                 ↓
  ┌───────────────────────────────────────────────────────────────┐
  │  PHASE 5: KUBERNETES ADMISSION CONTROL                        │
  │                                                               │
  │  kubectl apply / ArgoCD sync triggers admission webhooks      │
  │  OPA Gatekeeper / Kyverno enforce policies:                   │
  │  ├── Image must be signed (Cosign verified)                   │
  │  ├── Image must be from approved registry only                │
  │  ├── No :latest tag in production                             │
  │  ├── All containers must have resource limits                 │
  │  ├── No privileged containers                                 │
  │  ├── No hostNetwork / hostPID                                 │
  │  ├── runAsNonRoot: true enforced                              │
  │  └── readOnlyRootFilesystem: true enforced                    │
  └──────────────────────────────┬────────────────────────────────┘
                                 ↓ pod admitted
  ┌───────────────────────────────────────────────────────────────┐
  │  PHASE 6: RUNTIME SECURITY                                    │
  │                                                               │
  │  Pod running in cluster                                       │
  │  ├── Falco: behavioral anomaly detection                      │
  │  │   ├── Shell spawned in container → alert                   │
  │  │   ├── Unexpected outbound connection → alert               │
  │  │   ├── /etc/passwd read → alert                             │
  │  │   └── Privilege escalation attempt → alert + kill pod      │
  │  ├── NetworkPolicy: only whitelisted pod-to-pod traffic       │
  │  ├── ServiceAccount: least-privilege RBAC                     │
  │  └── Secrets: fetched from Vault/ASM — never in env vars      │
  └──────────────────────────────┬────────────────────────────────┘
                                 ↓
  ┌───────────────────────────────────────────────────────────────┐
  │  PHASE 7: CONTINUOUS COMPLIANCE                               │
  │                                                               │
  │  Prometheus + Grafana: security metric dashboards             │
  │  Falco Sidekick: routes alerts to PagerDuty / Slack           │
  │  Drata/Vanta: continuous SOC 2 / ISO 27001 evidence           │
  │  Weekly: automated CVE rescan of all running images           │
  └───────────────────────────────────────────────────────────────┘
```

**Simplified Linear Flow:**

```
Developer commits code
        ↓
Pre-commit: GitLeaks + SAST (local gate)
        ↓
CI: Secret scan + Dependency scan + SAST (pipeline gate)
        ↓
Docker Build: non-root, distroless, multi-stage
        ↓
Trivy: Image CVE scan + SBOM generation (image gate)
        ↓
Cosign: Image signing (provenance gate)
        ↓
Container Registry (signed image stored)
        ↓
Kubernetes Admission: OPA/Kyverno policy check (cluster gate)
        ↓
Pod Running → Falco runtime monitoring
        ↓
NetworkPolicy + Vault secrets + RBAC (zero-trust runtime)
        ↓
Continuous CVE scanning + compliance reporting
```

---

## 5. Component Explanation

### GitLeaks / TruffleHog (Pre-commit)
Scans every commit for patterns matching API keys, AWS credentials, private keys, JWT tokens. Blocks the commit before it reaches the remote. Integrated as a git pre-commit hook — developers never even push the secret.

### Snyk / Trivy (Dependency Scanning)
Parses `requirements.txt`, `package.json`, `go.mod`, `pom.xml` and cross-references against CVE databases. Identifies vulnerable transitive dependencies — the ones you never directly imported. Trivy also scans container layers, OS packages, and IaC files in a single binary.

### Cosign (Image Signing)
Signs Docker images using keyless signing (GitHub OIDC as identity provider). The signature proves the image was built by your specific CI pipeline, from a specific commit, at a specific time. Kubernetes admission can verify the signature — unsigned images are rejected.

### OPA Gatekeeper / Kyverno (Admission Control)
Kubernetes admission webhooks that evaluate every incoming resource against policy rules written in Rego (OPA) or YAML (Kyverno). Policies are stored in Git — policy-as-code. Violations are audited and optionally blocking (Enforce) or alerting-only (Audit).

### Falco (Runtime Security)
eBPF-based syscall monitoring. Watches every system call from every container in real time. Detects:
- Shells spawned inside running containers (attacker pivoting)
- Unexpected outbound network connections (data exfiltration)
- Sensitive file access (`/etc/shadow`, `/proc/*/mem`)
- Privilege escalation attempts

Fires alerts to Falco Sidekick → Slack/PagerDuty/SIEM within milliseconds.

### HashiCorp Vault / External Secrets Operator
Secrets never appear in Kubernetes manifests or environment variables hardcoded in configs. Vault issues dynamic short-lived credentials (e.g., AWS IAM roles, DB passwords that expire in 1 hour). ESO syncs secrets from cloud providers into Kubernetes Secrets at runtime.

---

## 6. Animation Storyboard

```
Scene 1 — Secret Caught Pre-Commit (0:00–0:10)
  Visual: Developer types git commit, pre-commit hook fires
  Text: "GitLeaks detects AWS_SECRET_KEY in config.py"
  Effect: commit blocked — red ❌, key highlighted in code

Scene 2 — CI Dependency Scan (0:10–0:20)
  Visual: GitHub Actions — Trivy scan runs, CVE list scrolls
  Text: "Trivy found: CRITICAL CVE-2021-44228 in log4j-2.14.1"
  Effect: pipeline fails, PR blocked from merging, Slack alert fires

Scene 3 — Secure Docker Build (0:20–0:30)
  Visual: Dockerfile renders on screen — distroless base, USER 1000, multi-stage
  Text: "Non-root, read-only filesystem, no secrets in layers"
  Effect: attack surface meter shrinks visually as each security directive is added

Scene 4 — Image Signing (0:30–0:38)
  Visual: Cosign icon signs image digest → shield icon appears on image
  Text: "Cosign signs image: provenance tied to git commit SHA"
  Effect: image in registry shows green signed badge

Scene 5 — Admission Control Blocks Bad Deploy (0:38–0:50)
  Visual: kubectl apply fires → OPA Gatekeeper intercepts
  Text: "Policy violation: container running as root → BLOCKED"
  Effect: deployment rejected, error message appears, Git commit required to fix

Scene 6 — Falco Runtime Alert (0:50–1:05)
  Visual: Pod running → attacker spawns shell inside container
  Text: "Falco: shell spawned in production pod — PagerDuty alert fired"
  Effect: Falco alert appears, pod highlighted red, PagerDuty fires, terminal session blocked

Scene 7 — Zero Trust Network (1:05–1:12)
  Visual: Pod-to-pod communication map — only whitelisted arrows appear
  Text: "NetworkPolicy: frontend can only reach backend. Backend cannot reach internet."
  Effect: unauthorized connection attempt shown as red X

Scene 8 — Compliance Dashboard (1:12–1:20)
  Visual: Grafana + Drata dashboard — SOC 2 controls green
  Text: "Continuous compliance: 147 controls passing, 0 critical findings"
  Effect: compliance percentage meter at 98%, automated evidence collected
```

---

## 7. Real Production Example

### Capital One (Post-2019 Breach Response)
After the 2019 breach (misconfigured WAF + SSRF), Capital One rebuilt their cloud security posture with defense-in-depth. Today they run OPA policies enforced at Kubernetes admission, Falco for runtime anomaly detection across 1,000+ microservices, and Vault for all secret management. Zero hardcoded credentials in any service.

### Stripe
Stripe's security team treats their Kubernetes policy library as a product with versioning, tests, and changelogs. Kyverno policies are PR-reviewed by both security and platform engineers. Every policy has an audit mode before enforcement mode — no surprise production breakage from new security rules.

### Goldman Sachs
Goldman's DevSecOps pipeline generates a signed SBOM for every container deployed to production. In the event of a zero-day (Log4Shell style), they can query their SBOM database cluster-wide — "which pods are running log4j-core?" — and get an answer in seconds, not days.

---

## 8. LinkedIn Post Content

---

🔐 **A secret was committed to GitHub at 9:02AM. Bots had scraped it by 9:05AM. The S3 bucket was being exfiltrated by 9:07AM.**

This is not hypothetical. This is a real incident pattern documented by GitHub's security team.

Security cannot be the last gate before production. It has to be every gate.

---

**The DevSecOps pipeline I'd build for any team shipping to Kubernetes:**

**Pre-Commit (Developer machine)**
→ GitLeaks: blocks commits containing API keys, tokens, private keys
→ Bandit/Semgrep: SAST catches SQL injection, hardcoded creds in code

**CI Pipeline (GitHub Actions)**
→ Trivy: scans every dependency for known CVEs
→ SonarQube: code quality + security hotspots
→ GATE: CRITICAL CVE = pipeline fails. Non-negotiable.

**Container Build**
→ Distroless or Alpine base (200MB → 8MB attack surface)
→ Non-root user (USER 1000)
→ Multi-stage build (no build tools in final image)
→ Cosign: signs the image — provenance tied to git commit

**Kubernetes Admission**
→ OPA Gatekeeper / Kyverno enforces:
  - No unsigned images
  - No :latest tag in production
  - No privileged containers
  - All pods must have resource limits
→ Violation = deployment rejected

**Runtime**
→ Falco: eBPF syscall monitoring — shell in container? Alert in milliseconds
→ NetworkPolicy: pods can only talk to what they're explicitly allowed to
→ Vault / ESO: no secrets in env vars, ever

**Continuous**
→ Weekly CVE rescan of all running images
→ Automated SOC 2 evidence via Drata/Vanta

---

The scary part? Most teams have none of this.
The encouraging part? Each layer can be added incrementally in a single sprint.

Which layer does your team currently have? What's missing? 👇

---

## 9. Hashtags

```
#DevSecOps
#Kubernetes
#CloudSecurity
#Falco
#SupplyChainSecurity
#SBOM
#OPA
#ZeroTrust
#PlatformEngineering
#ShiftLeft
```

---

## Trivy GitHub Actions Scan (Production Example)

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Dependency scan (filesystem)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'           # fail pipeline on HIGH/CRITICAL

      - name: Build Docker image
        run: docker build -t ${{ secrets.IMAGE_NAME }}:${{ github.sha }} .

      - name: Image scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'image'
          image-ref: '${{ secrets.IMAGE_NAME }}:${{ github.sha }}'
          severity: 'CRITICAL'
          exit-code: '1'

      - name: Generate SBOM
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'image'
          image-ref: '${{ secrets.IMAGE_NAME }}:${{ github.sha }}'
          format: 'cyclonedx'
          output: 'sbom.json'

      - name: Upload SBOM artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.json
```

## Kyverno Policy (Non-Root Enforcement)

```yaml
# kyverno-nonroot.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-run-as-non-root
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [production, staging]
      validate:
        message: "Containers must run as non-root (runAsNonRoot: true)"
        pattern:
          spec:
            securityContext:
              runAsNonRoot: true
            containers:
              - securityContext:
                  runAsNonRoot: true
                  readOnlyRootFilesystem: true
                  allowPrivilegeEscalation: false
```
