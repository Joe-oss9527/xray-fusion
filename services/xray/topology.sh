#!/usr/bin/env bash
# Topology service abstraction layer
# Provides service-level interface to topology context generation

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)"
. "${HERE}/lib/core.sh"

xray_topology::load() {
  local topology="$1"
  local topologies_dir
  topologies_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../topologies" && pwd)"
  
  if [[ ! -f "${topologies_dir}/${topology}.sh" ]]; then
    core::log error "Topology not found: ${topology}"
    return 1
  fi
  
  # Source the topology file which defines topology::context function
  . "${topologies_dir}/${topology}.sh"
}

xray_topology::get_context() {
  local topology="$1"
  
  # Load the topology (which defines topology::context function)
  xray_topology::load "${topology}"
  
  # Call the topology-specific context function
  topology::context
}

xray_topology::validate() {
  local topology="$1"
  local topologies_dir
  topologies_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../topologies" && pwd)"
  
  # Check if topology file exists
  if [[ ! -f "${topologies_dir}/${topology}.sh" ]]; then
    return 1
  fi
  
  # Check if topology file defines the required function
  if ! grep -q "topology::context" "${topologies_dir}/${topology}.sh"; then
    return 1
  fi
  
  return 0
}

xray_topology::list_available() {
  local topologies_dir
  topologies_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../topologies" && pwd)"
  
  find "${topologies_dir}" -name "*.sh" -type f -exec basename {} .sh \; | sort
}