#!/usr/bin/env bash
set -eu -o pipefail

# Script will:
# 1. Patch CVO to exclude CMO from being managed
# 2. Scale in-cluster CMO to 0
# 3. Change filter settings of Node Exporter

validate() {
    local ret=0

    [[ -z ${KUBECONFIG+xxx} ]] && {
        echo "ERROR: KUBECONFIG is not defined"
        ret=1
    }

    gojsontoyaml --help 2>/dev/null || {
        echo "ERROR: gojsontoyaml not found. See: https://github.com/brancz/gojsontoyaml#install"
        echo "Use this command to install: go install github.com/brancz/gojsontoyaml@latest"
        ret=1
    }

    jq --version >/dev/null || {
        echo "ERROR: jq not found. See: https://stedolan.github.io/jq/download/"
        ret=1
    }

    return $ret
}

kc() {
    kubectl -n openshift-monitoring "$@"
}

enable_managed_cmo() {
    # NOTE: we can't kubectl patch the spec.overrides since 'overrides'
    # does not define the patch strategy.
    # See: https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#notes-on-the-strategic-merge-patch
    #
    # So, as a workaround, we get the entire contents of the `spec.overrides` and
    # use jq to merge the override that puts "cluster-monitoring-operator" in
    # unmanaged state.

    local merge
    merge=$(
        cat <<-__EOF
    {
      "spec": {
        "overrides": [
          [ .spec | .? | .overrides[] | .? | select(.name != "cluster-monitoring-operator")] +
          [{
            "group": "apps",
            "kind": "Deployment",
            "name": "cluster-monitoring-operator",
            "namespace": "openshift-monitoring",
            "unmanaged": false
          }]
        ] | flatten
      }
    }
__EOF
    )

    local overrides
    overrides=$(kubectl get clusterversion version -o json | jq "$merge" | gojsontoyaml)
    kubectl patch clusterversion/version --type=merge -p="$overrides"

    echo "Enabling incluster operator "
    kc scale --replicas=1 deployment/cluster-monitoring-operator
}

patch_node_exporter() {
    # restore pattern of ignored netclass
    local overrides
    overrides=$(kc get daemonset node-exporter -o json | jq '.spec.template.spec.containers[0].args[5]="--collector.netclass.ignored-devices=^(veth.*|[a-f0-9]{15})$" ' | jq '{spec: .["spec"]}' | gojsontoyaml)
    kc patch daemonset/node-exporter --type=merge -p="$overrides"

}

main() {
    validate || exit 1
    enable_managed_cmo
    patch_node_exporter
}

main "$@"
