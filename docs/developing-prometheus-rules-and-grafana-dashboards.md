---
title: "Prometheus Rules and Grafana Dashboards"
description: "Create Prometheus Rules and Grafana Dashboards on top of kube-prometheus"
lead: "Create Prometheus Rules and Grafana Dashboards on top of kube-prometheus"
date: 2021-03-08T23:04:32+01:00
draft: false
images: []
menu:
  docs:
    parent: "kube"
weight: 650
toc: true
---

`kube-prometheus` ships with a set of default [Prometheus rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/) and [Grafana](http://grafana.com/) dashboards. At some point one might like to extend them, the purpose of this document is to explain how to do this.

All manifests of kube-prometheus are generated using [jsonnet](https://jsonnet.org/) and Prometheus rules and Grafana dashboards in specific follow the [Prometheus Monitoring Mixins proposal](https://docs.google.com/document/d/1A9xvzwqnFVSOZ5fD3blKODXfsat5fg6ZhnKu9LK3lB4/).

For both the Prometheus rules and the Grafana dashboards Kubernetes `ConfigMap`s are generated within kube-prometheus. In order to add additional rules and dashboards simply merge them onto the existing json objects. This document illustrates examples for rules as well as dashboards.

As a basis, all examples in this guide are based on the base example of the kube-prometheus [readme](../README.md):

[embedmd]:# (../example.jsonnet)
```jsonnet
local filter = {
  prometheus+: {
    prometheusRule+: {
      spec+: {
        groups: std.map(
          function(group)
            if group.name == 'prometheus' then
              group {
                rules: std.map(
                  function(rule)
                    if rule.alert == "PrometheusDuplicateTimestamps" then
                      rule {
                        "for": '1h',
                      }
                    else
                      rule,
                    group.rules
                )
              }
            else
              group,
          super.groups
        ),
      }
    }
  },
};

local kp =
  (import 'kube-prometheus/main.libsonnet') + filter +
  {
    values+:: {
      common+: {
        namespace: 'monitoring',
      },
    },
  };

{ 'setup/0namespace-namespace': kp.kubePrometheus.namespace } +
{
  ['setup/prometheus-operator-' + name]: kp.prometheusOperator[name]
  for name in std.filter((function(name) name != 'serviceMonitor' && name != 'prometheusRule'), std.objectFields(kp.prometheusOperator))
} +
// serviceMonitor and prometheusRule are separated so that they can be created after the CRDs are ready
{ 'prometheus-operator-serviceMonitor': kp.prometheusOperator.serviceMonitor } +
{ 'prometheus-operator-prometheusRule': kp.prometheusOperator.prometheusRule } +
{ 'kube-prometheus-prometheusRule': kp.kubePrometheus.prometheusRule } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['blackbox-exporter-' + name]: kp.blackboxExporter[name] for name in std.objectFields(kp.blackboxExporter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) }
```

## Prometheus rules

### Alerting rules

According to the [Prometheus Monitoring Mixins proposal](https://docs.google.com/document/d/1A9xvzwqnFVSOZ5fD3blKODXfsat5fg6ZhnKu9LK3lB4/) Prometheus alerting rules are under the key `prometheusAlerts` in the top level object, so in order to add an additional alerting rule, we can simply merge an extra rule into the existing object.

The format is exactly the Prometheus format, so there should be no changes necessary should you have existing rules that you want to include.

> Note that alerts can just as well be included into this file, using the jsonnet `import` function. In this example it is just inlined in order to demonstrate their use in a single file.

[embedmd]:# (../examples/prometheus-additional-alert-rule-example.jsonnet)
```jsonnet
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
  exampleApplication: {
    prometheusRuleExample: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        name: 'my-prometheus-rule',
        namespace: $.values.common.namespace,
      },
      spec: {
        groups: [
          {
            name: 'example-group',
            rules: [
              {
                alert: 'ExampleAlert',
                expr: 'vector(1)',
                labels: {
                  severity: 'warning',
                },
                annotations: {
                  description: 'This is an example alert.',
                },
              },
            ],
          },
        ],
      },
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['example-application-' + name]: kp.exampleApplication[name] for name in std.objectFields(kp.exampleApplication) }
```

### Recording rules

In order to add a recording rule, simply do the same with the `prometheusRules` field.

> Note that rules can just as well be included into this file, using the jsonnet `import` function. In this example it is just inlined in order to demonstrate their use in a single file.

[embedmd]:# (../examples/prometheus-additional-recording-rule-example.jsonnet)
```jsonnet
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
  exampleApplication: {
    prometheusRuleExample: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        name: 'my-prometheus-rule',
        namespace: $.values.common.namespace,
      },
      spec: {
        groups: [
          {
            name: 'example-group',
            rules: [
              {
                record: 'some_recording_rule_name',
                expr: 'vector(1)',
              },
            ],
          },
        ],
      },
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['example-application-' + name]: kp.exampleApplication[name] for name in std.objectFields(kp.exampleApplication) }
```

### Pre-rendered rules

We acknowledge, that users may need to transition existing rules, and therefore allow an option to add additional pre-rendered rules. Luckily the yaml and json formats are very close so the yaml rules just need to be converted to json without any manual interaction needed. Just a tool to convert yaml to json is needed:

```
go get -u -v github.com/brancz/gojsontoyaml
```

And convert the existing rule file:

```
cat existingrule.yaml | gojsontoyaml -yamltojson > existingrule.json
```

Then import it in jsonnet:

[embedmd]:# (../examples/prometheus-additional-rendered-rule-example.jsonnet)
```jsonnet
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+: {
      namespace: 'monitoring',
    },
  },
  exampleApplication: {
    prometheusRuleExample: {
      apiVersion: 'monitoring.coreos.com/v1',
      kind: 'PrometheusRule',
      metadata: {
        name: 'my-prometheus-rule',
        namespace: $.values.common.namespace,
      },
      spec: {
        groups: (import 'existingrule.json').groups,
      },
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
{ ['example-application-' + name]: kp.exampleApplication[name] for name in std.objectFields(kp.exampleApplication) }
```
### Changing default rules

Along with adding additional rules, we give the user the option to filter or adjust the existing rules imported by `kube-prometheus/kube-prometheus.libsonnet`. The recording rules can be found in [kube-prometheus/rules](../jsonnet/kube-prometheus/rules) and [kubernetes-mixin/rules](https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/rules) while the alerting rules can be found in [kube-prometheus/alerts](../jsonnet/kube-prometheus/alerts) and [kubernetes-mixin/alerts](https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/alerts).

Knowing which rules to change, the user can now use functions from the [Jsonnet standard library](https://jsonnet.org/ref/stdlib.html) to make these changes. Below are examples of both a filter and an adjustment being made to the default rules. These changes can be assigned to a local variable and then added to the `local kp` object as seen in the examples above.

#### Filter
Here the alert `KubeStatefulSetReplicasMismatch` is being filtered out of the group `kubernetes-apps`. The default rule can be seen [here](https://github.com/kubernetes-monitoring/kubernetes-mixin/blob/master/alerts/apps_alerts.libsonnet).
```jsonnet
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
```
#### Adjustment
Here the expression for the alert used above is updated from its previous value. The default rule can be seen [here](https://github.com/kubernetes-monitoring/kubernetes-mixin/blob/master/alerts/apps_alerts.libsonnet).
```jsonnet
local update = {
  prometheusAlerts+:: {
    groups: std.map(
      function(group)
        if group.name == 'kubernetes-apps' then
          group {
            rules: std.map(
              function(rule)
                if rule.alert == "KubeStatefulSetReplicasMismatch" then
                  rule {
                    expr: "kube_statefulset_status_replicas_ready{job=\"kube-state-metrics\",statefulset!=\"vault\"} != kube_statefulset_status_replicas{job=\"kube-state-metrics\",statefulset!=\"vault\"}"
                  }
                else
                  rule,
                group.rules
            )
          }
        else
          group,
      super.groups
    ),
  },
};
```
Using the example from above about adding in pre-rendered rules, the new local variables can be added in as follows:
```jsonnet
local kp = (import 'kube-prometheus/kube-prometheus.libsonnet') + filter + update + {
    prometheusAlerts+:: (import 'existingrule.json'),
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['prometheus-adapter-' + name]: kp.prometheusAdapter[name] for name in std.objectFields(kp.prometheusAdapter) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```
## Dashboards

Dashboards can either be added using jsonnet or simply a pre-rendered json dashboard.

### Jsonnet dashboard

We recommend using the [grafonnet](https://github.com/grafana/grafonnet-lib/) library for jsonnet, which gives you a simple DSL to generate Grafana dashboards. Following the [Prometheus Monitoring Mixins proposal](https://docs.google.com/document/d/1A9xvzwqnFVSOZ5fD3blKODXfsat5fg6ZhnKu9LK3lB4/) additional dashboards are added to the `grafanaDashboards` key, located in the top level object. To add new jsonnet dashboards, simply add one.

> Note that dashboards can just as well be included into this file, using the jsonnet `import` function. In this example it is just inlined in order to demonstrate their use in a single file.

[embedmd]:# (../examples/grafana-additional-jsonnet-dashboard-example.jsonnet)
```jsonnet
local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;

local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+:: {
      namespace: 'monitoring',
    },
    grafana+: {
      dashboards+:: {
        'my-dashboard.json':
          dashboard.new('My Dashboard')
          .addTemplate(
            {
              current: {
                text: 'Prometheus',
                value: 'Prometheus',
              },
              hide: 0,
              label: null,
              name: 'datasource',
              options: [],
              query: 'prometheus',
              refresh: 1,
              regex: '',
              type: 'datasource',
            },
          )
          .addRow(
            row.new()
            .addPanel(graphPanel.new('My Panel', span=6, datasource='$datasource')
                      .addTarget(prometheus.target('vector(1)')))
          ),
      },
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

### Pre-rendered Grafana dashboards

As jsonnet is a superset of json, the jsonnet `import` function can be used to include Grafana dashboard json blobs. In this example we are importing a [provided example dashboard](../examples/example-grafana-dashboard.json).

[embedmd]:# (../examples/grafana-additional-rendered-dashboard-example.jsonnet)
```jsonnet
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+:: {
      namespace: 'monitoring',
    },
    grafana+: {
      dashboards+:: {  // use this method to import your dashboards to Grafana
        'my-dashboard.json': (import 'example-grafana-dashboard.json'),
      },
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

In case you have lots of json dashboard exported out from grafana UI the above approach is going to take lots of time to improve performance we can use `rawDashboards` field and provide it's value as json string by using `importstr`
[embedmd]:# (../examples/grafana-additional-rendered-dashboard-example-2.jsonnet)
```jsonnet
local kp = (import 'kube-prometheus/main.libsonnet') + {
  values+:: {
    common+:: {
      namespace: 'monitoring',
    },
    grafana+: {
      rawDashboards+:: {
        'my-dashboard.json': (importstr 'example-grafana-dashboard.json'),
      },
    },
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
```

### Mixins

Kube-prometheus comes with a couple of default mixins as the Kubernetes-mixin and the Node-exporter mixin, however there [are many more mixins](https://monitoring.mixins.dev/). To use other mixins Kube-prometheus has a jsonnet library for creating a Kubernetes PrometheusRule CRD and Grafana dashboards from a mixin. Below is an example of creating a mixin object that has Prometheus rules and Grafana dashboards:

```jsonnet
// Import the library function for adding mixins
local addMixin = (import 'kube-prometheus/lib/mixin.libsonnet');

// Create your mixin
local myMixin = addMixin({
  name: 'myMixin',
  mixin: import 'my-mixin/mixin.libsonnet',
});
```

The myMixin object will have two objects - `prometheusRules` and `grafanaDashboards`. The `grafanaDashboards` object will be needed to be added to the `dashboards` field as in the example below:

```jsonnet
values+:: {
  grafana+:: {
    dashboards+:: myMixin.grafanaDashboards
```

The `prometheusRules` object is a PrometheusRule Kubernetes CRD and it should be defined as its own jsonnet object. If you define multiple mixins in a single jsonnet object there is a possibility that they will overwrite each others' configuration and there will be unintended effects. Therefore, use the `prometheusRules` object as its own jsonnet object:

```jsonnet
...
{ ['kubernetes-' + name]: kp.kubernetesControlPlane[name] for name in std.objectFields(kp.kubernetesControlPlane) }
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ 'external-mixins/my-mixin-prometheus-rules': myMixin.prometheusRules } // one object for each mixin
```

As mentioned above each mixin is configurable and you would configure the mixin as in the example below:

```jsonnet
local myMixin = addMixin({
  name: 'myMixin',
  mixin: (import 'my-mixin/mixin.libsonnet') + {
    _config+:: {
      myMixinSelector: 'my-selector',
      interval: '30d', // example
    },
  },
});
```

The library has also two optional parameters - the namespace for the `PrometheusRule` CRD and the dashboard folder for the Grafana dashboards. The below example shows how to use both:

```jsonnet
local myMixin = addMixin({
  name: 'myMixin',
  namespace: 'prometheus', // default is monitoring
  dashboardFolder: 'Observability',
  mixin: (import 'my-mixin/mixin.libsonnet') + {
    _config+:: {
      myMixinSelector: 'my-selector',
      interval: '30d', // example
    },
  },
});
```

The created `prometheusRules` object will have the metadata field `namespace` added and the usage will remain the same. However, the `grafanaDasboards` will be added to the `folderDashboards` field instead of the `dashboards` field as shown in the example below:

```jsonnet
values+:: {
  grafana+:: {
    folderDashboards+:: {
        Kubernetes: {
            ...
        },
        Misc: {
            'grafana-home.json': import 'dashboards/misc/grafana-home.json',
        },
    } + myMixin.grafanaDashboards
```

Full example of including etcd mixin using method described above:

[embedmd]:# (../examples/mixin-inclusion.jsonnet)
```jsonnet
local addMixin = (import 'kube-prometheus/lib/mixin.libsonnet');
local etcdMixin = addMixin({
  name: 'etcd',
  mixin: (import 'github.com/etcd-io/etcd/contrib/mixin/mixin.libsonnet') + {
    _config+: {},  // mixin configuration object
  },
});

local kp = (import 'kube-prometheus/main.libsonnet') +
           {
             values+:: {
               common+: {
                 namespace: 'monitoring',
               },
               grafana+: {
                 // Adding new dashboard to grafana. This will modify grafana configMap with dashboards
                 dashboards+: etcdMixin.grafanaDashboards,
               },
             },
           };

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) } +
// Rendering prometheusRules object. This is an object compatible with prometheus-operator CRD definition for prometheusRule
{ 'external-mixins/etcd-mixin-prometheus-rules': etcdMixin.prometheusRules }
```
