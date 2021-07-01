local filter = {
  prometheusAlerts+:: {
    groups: std.map(
      function(group)
        if group.name == 'kubernetes-apps' then
          group {
            rules: std.filter(function(rule)
              rule.alert != "KubeStatefulSetReplicasMismatch",
              group.rules
            )
          }
        else
          group,
      super.groups
    ),
  },
};