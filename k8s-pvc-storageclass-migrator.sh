#!/usr/bin/env bash

set -euo pipefail

# Function to display usage information
usage() {
  echo "Usage: $0 [--wait-for-bound] [--dest-sc=<storage-class>] <PVC_NAME> [NAMESPACE]"
  echo "Options:"
  echo "  --wait-for-bound              Wait for PVCs to be bound before proceeding"
  echo "  --dest-sc=<storage-class>     Set the storage class for the new PVCs"
  echo "If namespace is not provided, the current context's namespace will be used."
  exit 1
}

# Function to handle errors
handle_error() {
  echo "Error occurred on line $1"
  exit 1
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Parse command line arguments
WAIT_FOR_BOUND=false
DEST_SC=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --wait-for-bound)
      WAIT_FOR_BOUND=true
      shift
      ;;
    --dest-sc=*)
      DEST_SC="${1#*=}"
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Check for required arguments
[[ $# -lt 1 ]] && usage

# Set variables
PVC_NAME=$1
NAMESPACE=${2:-$(kubectl config view --minify -o jsonpath='{..namespace}')}
NEW_PVC_NAME="${PVC_NAME}-tmp"

# Function to check if a PVC is bound to a pod
check_pvc_bound() {
  local pvc_name=$1
  local namespace=$2
  local pod_using_pvc

  kubectl get pvc "$pvc_name" -n "$namespace" -o jsonpath='{.status.phase}' | grep -q "Bound" || return 1
  pod_using_pvc=$(kubectl get pods -n "$namespace" -o jsonpath="{.items[?(@.spec.volumes[*].persistentVolumeClaim.claimName=='$pvc_name')].metadata.name}")
  [[ -n $pod_using_pvc ]] || return 1
  echo "PVC $pvc_name is bound to pod $pod_using_pvc."
  return 0
}

# Function to wait for PVC to be bound
wait_for_pvc_bound() {
  local pvc_name=$1
  local namespace=$2
  local timeout=300  # 5 minutes
  local start_time=$(date +%s)

  while ! kubectl get pvc "$pvc_name" -n "$namespace" -o jsonpath='{.status.phase}' | grep -q "Bound"; do
    if [ $(($(date +%s) - start_time)) -gt $timeout ]; then
      echo "Timeout waiting for PVC $pvc_name to be bound."
      exit 1
    fi
    echo "Waiting for PVC $pvc_name to be bound..."
    sleep 5
  done
  echo "PVC $pvc_name is now bound."
}

# Check if the PVC exists
kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" &> /dev/null || { echo "PVC $PVC_NAME does not exist in namespace $NAMESPACE."; exit 1; }

# Create new PVC
echo "Creating new temporary PVC: $NEW_PVC_NAME"
NEW_PVC_YAML=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o yaml | \
NEW_PVC_NAME=$NEW_PVC_NAME yq eval '
  .metadata.name = env(NEW_PVC_NAME) |
  del(.metadata | .annotations, .finalizers, .managedFields, .resourceVersion, .uid, .creationTimestamp) |
  del(.spec | .volumeName, .volumeMode) |
  del(.status) |
  .spec.resources.requests.storage = (.spec.resources.requests.storage // "10Gi")
')

if [[ -n "$DEST_SC" ]]; then
  NEW_PVC_YAML=$(echo "$NEW_PVC_YAML" | yq eval ".spec.storageClassName = \"$DEST_SC\"")
fi

echo "$NEW_PVC_YAML" | kubectl apply -f -

if $WAIT_FOR_BOUND; then
  wait_for_pvc_bound "$NEW_PVC_NAME" "$NAMESPACE"
fi

# Migrate data
echo "Migrating data from $PVC_NAME to $NEW_PVC_NAME..."
kubectl pv-migrate migrate "$PVC_NAME" "$NEW_PVC_NAME" -n "$NAMESPACE" -s svc

echo "Waiting for the original PVC $PVC_NAME to be unbound..."
while check_pvc_bound "$PVC_NAME" "$NAMESPACE"; do
  echo "PVC is still bound. Waiting 10 seconds..."
  sleep 10
done

# Replace original PVC
echo "Replacing original PVC: $PVC_NAME"
kubectl delete pvc "$PVC_NAME" -n "$NAMESPACE"
FINAL_PVC_YAML=$(kubectl get pvc "$NEW_PVC_NAME" -n "$NAMESPACE" -o yaml | \
PVC_NAME=$PVC_NAME yq eval '
  .metadata.name = env(PVC_NAME) |
  del(.metadata | .annotations, .finalizers, .managedFields, .resourceVersion, .uid, .creationTimestamp) |
  del(.spec | .volumeName, .volumeMode) |
  del(.status)
')

if [[ -n "$DEST_SC" ]]; then
  FINAL_PVC_YAML=$(echo "$FINAL_PVC_YAML" | yq eval ".spec.storageClassName = \"$DEST_SC\"")
fi

echo "$FINAL_PVC_YAML" | kubectl apply -f -

if $WAIT_FOR_BOUND; then
  wait_for_pvc_bound "$PVC_NAME" "$NAMESPACE"
fi

# Final data migration
echo "Performing final data migration from $NEW_PVC_NAME to $PVC_NAME..."
kubectl pv-migrate migrate "$NEW_PVC_NAME" "$PVC_NAME" -n "$NAMESPACE" -s svc

# Cleanup
echo "Cleaning up: Deleting temporary PVC $NEW_PVC_NAME"
kubectl delete pvc "$NEW_PVC_NAME" -n "$NAMESPACE"

echo "PVC migration completed successfully."
