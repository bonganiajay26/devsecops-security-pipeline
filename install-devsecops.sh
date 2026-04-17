#!/bin/bash
# install-devsecops.sh — Install complete DevSecOps security stack

set -e

echo "=== Installing DevSecOps Security Stack ==="

# ── Install Kyverno (Policy Engine) ──
echo "[1/4] Installing Kyverno..."
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set replicaCount=3

echo "Waiting for Kyverno to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/kyverno -n kyverno

# ── Apply all Kyverno policies ──
echo "[2/4] Applying security policies..."
kubectl apply -f policies/kyverno-nonroot.yaml
kubectl apply -f policies/kyverno-no-latest.yaml
kubectl apply -f policies/kyverno-resource-limits.yaml
kubectl apply -f policies/kyverno-approved-registries.yaml
kubectl apply -f policies/kyverno-no-privileged.yaml
kubectl apply -f policies/network-policy.yaml

# ── Install Falco (Runtime Security) ──
echo "[3/4] Installing Falco..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --set driver.kind=ebpf \
  --set falcosidekick.enabled=true \
  --set falcosidekick.config.slack.webhookurl="YOUR_SLACK_WEBHOOK_URL" \
  --set falcosidekick.config.slack.minimumpriority=warning \
  --set falcosidekick.config.pagerduty.routingkey="YOUR_PAGERDUTY_KEY" \
  --set falcosidekick.config.pagerduty.minimumpriority=critical \
  --set customRules."custom-rules\.yaml"="$(cat falco/falco-rules.yaml)"

# ── Install pre-commit hooks ──
echo "[4/4] Setting up pre-commit hooks..."
pip install pre-commit
pre-commit install
pre-commit install --hook-type commit-msg

echo ""
echo "=== DevSecOps Stack Installed ==="
echo ""
echo "Kyverno policies active:"
kubectl get clusterpolicies
echo ""
echo "Falco running:"
kubectl get pods -n falco
echo ""
echo "Pre-commit hooks:"
pre-commit run --all-files || true
echo ""
echo "Test a policy violation:"
echo "  kubectl run root-test --image=nginx:latest -n production"
echo "  (This should be BLOCKED by Kyverno)"
