# DevSecOps Security Pipeline
> Shift-left security at every layer — Trivy + Falco + Kyverno + Cosign + Vault

![Security](https://img.shields.io/badge/DevSecOps-Security-red?style=for-the-badge)
![Trivy](https://img.shields.io/badge/Trivy-Scanner-1904DA?style=for-the-badge)
![Falco](https://img.shields.io/badge/Falco-Runtime-00AEC7?style=for-the-badge)

---

## Architecture Overview

```
Developer git commit
        ↓
Pre-commit: GitLeaks + Bandit (local gate)
        ↓
CI: Secret scan + Dependency scan + SAST (pipeline gate)
        ↓
Docker Build: non-root, distroless, multi-stage
        ↓
Trivy: Image CVE scan + SBOM generation (image gate)
        ↓
Cosign: Image signing (provenance gate)
        ↓
Kubernetes Admission: Kyverno policy enforcement (cluster gate)
        ↓
Runtime: Falco eBPF monitoring + NetworkPolicy + Vault secrets
        ↓
Continuous CVE rescan + SOC 2 compliance evidence
```

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| kubectl | v1.28+ | [Install](https://kubernetes.io/docs/tasks/tools/) |
| Helm | v3.12+ | [Install](https://helm.sh/docs/intro/install/) |
| Docker | 24+ | [Install](https://docs.docker.com/get-docker/) |
| Python | 3.11+ | [Install](https://python.org) |
| pre-commit | latest | `pip install pre-commit` |
| Trivy | latest | [Install](https://aquasecurity.github.io/trivy/latest/getting-started/installation/) |
| Cosign | latest | [Install](https://docs.sigstore.dev/cosign/installation/) |

---

## Execution Steps

### Step 1 — Install Pre-commit Hooks (Developer Machine)

```bash
# Install pre-commit
pip install pre-commit

# Install hooks defined in .pre-commit-config.yaml
pre-commit install
pre-commit install --hook-type commit-msg

# Test hooks run on all files
pre-commit run --all-files

# Now every git commit will automatically run:
# - GitLeaks: secret scanning
# - Bandit: Python SAST
# - Hadolint: Dockerfile linting
# - YAML/JSON validation
```

### Step 2 — Scan Dependencies (CI or Local)

```bash
# Install Trivy
brew install trivy  # macOS
# or
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh

# Scan filesystem for vulnerable dependencies
trivy fs . --severity CRITICAL,HIGH --exit-code 1

# Scan requirements.txt specifically
trivy fs . --scanners vuln --severity CRITICAL,HIGH
```

### Step 3 — Build Secure Docker Image

```bash
# Build using the hardened Dockerfile
docker build -f Dockerfile.secure -t myapp:latest .

# What makes it secure:
# - python:3.11-slim base (minimal attack surface)
# - Multi-stage build (no build tools in final image)
# - Non-root user (USER 1000)
# - No secrets in layers
```

### Step 4 — Scan Docker Image with Trivy

```bash
# Scan image for CVEs
trivy image myapp:latest --severity CRITICAL --exit-code 1

# Generate SBOM (Software Bill of Materials)
trivy image myapp:latest --format cyclonedx --output sbom.json

# View SBOM
cat sbom.json | jq '.components[].name'

# Scan image for misconfigurations
trivy image myapp:latest --scanners misconfig
```

### Step 5 — Sign Image with Cosign

```bash
# Push image to registry first
docker tag myapp:latest YOUR_USERNAME/myapp:latest
docker push YOUR_USERNAME/myapp:latest

# Sign image (keyless — uses GitHub OIDC in CI)
cosign sign --yes YOUR_USERNAME/myapp:latest

# Verify the signature
cosign verify \
  --certificate-identity-regexp=https://github.com/YOUR_ORG \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  YOUR_USERNAME/myapp:latest
```

### Step 6 — Install Kyverno (Policy Engine)

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set replicaCount=1

# Wait for Kyverno to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/kyverno -n kyverno

kubectl get pods -n kyverno
```

### Step 7 — Apply Security Policies

```bash
# Apply all Kyverno policies
kubectl apply -f policies/kyverno-nonroot.yaml
kubectl apply -f policies/kyverno-no-latest.yaml
kubectl apply -f policies/kyverno-resource-limits.yaml
kubectl apply -f policies/kyverno-approved-registries.yaml
kubectl apply -f policies/kyverno-no-privileged.yaml

# Verify policies are active
kubectl get clusterpolicies

# Test policy enforcement (should be BLOCKED)
kubectl run root-test --image=nginx:latest -n production
# Expected: Error from server: admission webhook denied the request
```

### Step 8 — Apply Network Policies (Zero-Trust)

```bash
kubectl apply -f policies/network-policy.yaml

# Verify default-deny is active
kubectl get networkpolicy -n production

# Test: pod-to-pod traffic should only work if explicitly allowed
kubectl exec -it <pod-name> -n production -- curl http://other-service
```

### Step 9 — Install Falco (Runtime Security)

```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl="YOUR_SLACK_WEBHOOK" \
  --set falcosidekick.config.slack.minimumpriority=warning \
  --set customRules."custom-rules\.yaml"="$(cat falco/falco-rules.yaml)"

kubectl get pods -n falco
```

---

## Testing Security Controls

### Test Pre-commit Secret Detection

```bash
# Try to commit a fake AWS key (should be BLOCKED)
echo "AWS_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" >> test.txt
git add test.txt
git commit -m "test"
# Expected: GitLeaks blocks the commit
rm test.txt
```

### Test Kyverno — Block Root Container

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: root-pod-test
  namespace: production
spec:
  containers:
    - name: test
      image: nginx:1.25
      securityContext:
        runAsUser: 0
EOF
# Expected: admission webhook denied — runAsNonRoot violation
```

### Test Falco — Shell Detection

```bash
# Exec into a running pod (Falco will alert on this)
kubectl exec -it <pod-name> -n production -- /bin/sh
# Check Falco logs for the alert
kubectl logs -n falco -l app=falco --tail=20
```

### Verify CVE Scan in CI

```bash
# The GitHub Actions workflow runs automatically on push
# View results at: GitHub repo → Security → Code scanning alerts
```

---

## Cleanup

```bash
helm uninstall falco -n falco
helm uninstall kyverno -n kyverno
kubectl delete -f policies/
pre-commit uninstall
```

---

## Files

| File | Description |
|------|-------------|
| `.github/workflows/security-scan.yml` | Full DevSecOps CI: TruffleHog + Semgrep + Trivy + Cosign |
| `.pre-commit-config.yaml` | GitLeaks + Bandit + Hadolint pre-commit hooks |
| `Dockerfile.secure` | Hardened multi-stage non-root Docker image |
| `policies/kyverno-nonroot.yaml` | Enforce runAsNonRoot on all pods |
| `policies/kyverno-no-latest.yaml` | Block :latest tag in production |
| `policies/kyverno-resource-limits.yaml` | Require CPU/memory limits |
| `policies/kyverno-approved-registries.yaml` | Allowlist container registries |
| `policies/kyverno-no-privileged.yaml` | Block privileged containers |
| `policies/network-policy.yaml` | Zero-trust deny-all + whitelist rules |
| `falco/falco-rules.yaml` | Custom Falco rules: shell, outbound, privesc |
| `install-devsecops.sh` | One-shot install: Kyverno + Falco + pre-commit |
| `ARCHITECTURE.md` | Full diagram + LinkedIn post + storyboard |
