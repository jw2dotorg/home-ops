#!/bin/bash

# Function to convert memory from Ki/Mi/Gi to Gi for easy calculation
convert_to_gb() {
  local value=$1
  case "$value" in
    *Ki) echo "scale=2; ${value%Ki}/1024/1024" | bc ;;
    *Mi) echo "scale=2; ${value%Mi}/1024" | bc ;;
    *Gi) echo "scale=2; ${value%Gi}" | bc ;;
    *) echo "0" ;; # In case of unexpected format
  esac
}

# Function to convert CPU from m to cores for easy calculation
convert_to_cores() {
  local value=$1
  case "$value" in
    *m) echo "scale=2; ${value%m}/1000" | bc ;;
    *) echo "$value" ;; # If already in cores
  esac
}

# List all nodes
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  # Get allocatable memory and CPU on the node, converting memory to GB and CPU to cores
  allocatable_mem=$(kubectl get node "$node" -o jsonpath='{.status.allocatable.memory}')
  allocatable_mem_gb=$(convert_to_gb "$allocatable_mem")

  allocatable_cpu=$(kubectl get node "$node" -o jsonpath='{.status.allocatable.cpu}')
  allocatable_cpu_cores=$(convert_to_cores "$allocatable_cpu")

  # Get memory and CPU requested by all pods on the node
  requested_mem=$(kubectl get pods --all-namespaces --field-selector spec.nodeName="$node" -o jsonpath='{range .items[*]}{.spec.containers[*].resources.requests.memory}{" "}{end}')
  requested_cpu=$(kubectl get pods --all-namespaces --field-selector spec.nodeName="$node" -o jsonpath='{range .items[*]}{.spec.containers[*].resources.requests.cpu}{" "}{end}')

  # Sum the requested memory and CPU, converting each to GB and cores
  requested_mem_gb=0
  for mem in $requested_mem; do
    mem_gb=$(convert_to_gb "$mem")
    requested_mem_gb=$(echo "$requested_mem_gb + $mem_gb" | bc)
  done

  requested_cpu_cores=0
  for cpu in $requested_cpu; do
    cpu_cores=$(convert_to_cores "$cpu")
    requested_cpu_cores=$(echo "$requested_cpu_cores + $cpu_cores" | bc)
  done

  # Calculate free memory in GB and free CPU in cores
  free_mem_gb=$(echo "$allocatable_mem_gb - $requested_mem_gb" | bc)
  free_cpu_cores=$(echo "$allocatable_cpu_cores - $requested_cpu_cores" | bc)

  # Print results
  echo "Node: $node"
  echo "Allocatable Memory: $allocatable_mem_gb GB"
  echo "Requested Memory: $requested_mem_gb GB"
  echo "Free Memory: $free_mem_gb GB"
  echo "Allocatable CPU: $allocatable_cpu_cores cores"
  echo "Requested CPU: $requested_cpu_cores cores"
  echo "Free CPU: $free_cpu_cores cores"
  echo "---------------------------------"
done
