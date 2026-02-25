#!/bin/bash
# =============================================================================
# TES Integration Test Task Script
# =============================================================================
# Submits a simple TES task to the cluster-internal TES service and polls until
# completion. Runs via:
#   az aks command invoke --command "bash test-tes-task.sh" --file test-tes-task.sh
#
# The runner pod created by `az aks command invoke` has kubectl available and
# runs inside the cluster network, so it can reach private services directly.
# =============================================================================

set -euo pipefail

TES_NS="${TES_NAMESPACE:-tes}"
TES_SVC_URL="http://tes.${TES_NS}.svc.cluster.local"
TEST_POD_NAME="tes-integ-$(date +%s)"
TASK_TIMEOUT="${TASK_TIMEOUT:-600}"
POLL_INTERVAL=15

echo "=== TES Bicep Private Deployment Integration Test ==="
echo "Namespace : ${TES_NS}"
echo "TES URL   : ${TES_SVC_URL}"
echo "Timeout   : ${TASK_TIMEOUT}s"
echo ""

# Clean up the test pod on exit (success or failure)
cleanup() {
    kubectl delete pod "${TEST_POD_NAME}" -n "${TES_NS}" --ignore-not-found=true 2>/dev/null || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Step 1: Verify TES deployment is available
# ---------------------------------------------------------------------------
echo "Step 1: Verifying TES deployment readiness..."
if kubectl wait deployment/tes -n "${TES_NS}" --for=condition=Available --timeout=120s 2>/dev/null; then
    echo "  ✓ TES deployment is available"
else
    echo "  ✗ TES deployment not available - is TES deployed to the cluster?"
    echo "    Deploy TES first (e.g. via deploy-tes-on-azure or the Helm chart)"
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: Submit a test TES task via a temporary curl pod inside the cluster
# ---------------------------------------------------------------------------
echo ""
echo "Step 2: Submitting test TES task..."

# Compact JSON payload — must be single-line for kubectl arg passing
TASK_PAYLOAD='{"name":"integration-test","description":"Bicep private deployment integration test","executors":[{"image":"ubuntu:24.04","command":["/bin/sh","-c","echo Integration test OK && date && echo hostname=$(hostname)"]}],"resources":{"preemptible":true},"tags":{"integration-test":"true"}}'

kubectl run "${TEST_POD_NAME}" \
    --image=curlimages/curl:latest \
    --restart=Never \
    -n "${TES_NS}" \
    --labels="app=tes-integration-test" \
    -- sh -c "curl -sf -X POST -H 'Content-Type: application/json' -d '${TASK_PAYLOAD}' '${TES_SVC_URL}/v1/tasks'"

# Wait for the submit pod to finish
if ! kubectl wait "pod/${TEST_POD_NAME}" -n "${TES_NS}" \
        --for=condition=Succeeded --timeout=60s 2>/dev/null; then
    echo "  ✗ Submit pod did not succeed"
    kubectl logs "${TEST_POD_NAME}" -n "${TES_NS}" 2>/dev/null || true
    exit 1
fi

RESPONSE=$(kubectl logs "${TEST_POD_NAME}" -n "${TES_NS}")
TASK_ID=$(echo "${RESPONSE}" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null || echo "")
kubectl delete pod "${TEST_POD_NAME}" -n "${TES_NS}" --ignore-not-found=true 2>/dev/null || true

if [ -z "${TASK_ID}" ]; then
    echo "  ✗ Failed to parse task ID from response: ${RESPONSE}"
    exit 1
fi
echo "  ✓ Task submitted — ID: ${TASK_ID}"

# ---------------------------------------------------------------------------
# Step 3: Poll the task until it reaches a terminal state
# ---------------------------------------------------------------------------
echo ""
echo "Step 3: Monitoring task completion (max ${TASK_TIMEOUT}s)..."

ELAPSED=0
while [ "${ELAPSED}" -lt "${TASK_TIMEOUT}" ]; do
    POLL_POD="${TEST_POD_NAME}-p"

    kubectl run "${POLL_POD}" \
        --image=curlimages/curl:latest \
        --restart=Never \
        -n "${TES_NS}" \
        -- sh -c "curl -sf '${TES_SVC_URL}/v1/tasks/${TASK_ID}?view=MINIMAL'" 2>/dev/null || true

    kubectl wait "pod/${POLL_POD}" -n "${TES_NS}" \
        --for=condition=Succeeded --timeout=30s 2>/dev/null || true

    STATUS_RESP=$(kubectl logs "${POLL_POD}" -n "${TES_NS}" 2>/dev/null || echo "{}")
    kubectl delete pod "${POLL_POD}" -n "${TES_NS}" --ignore-not-found=true 2>/dev/null || true

    TASK_STATE=$(echo "${STATUS_RESP}" | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('state','UNKNOWN'))" \
        2>/dev/null || echo "UNKNOWN")

    echo "  [${ELAPSED}s] state=${TASK_STATE}"

    case "${TASK_STATE}" in
        COMPLETE)
            echo ""
            echo "  ✓ TES task completed successfully!"
            exit 0
            ;;
        EXECUTOR_ERROR|SYSTEM_ERROR|CANCELED)
            echo ""
            echo "  ✗ TES task terminated with state: ${TASK_STATE}"
            exit 1
            ;;
    esac

    sleep "${POLL_INTERVAL}"
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

echo "  ✗ Timed out after ${TASK_TIMEOUT}s waiting for task ${TASK_ID}"
exit 1
