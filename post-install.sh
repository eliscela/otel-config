#!/bin/bash

# Install Cert-Manager
printf "\n### Installing cert-manager in the cert-manager namespace... ###\n"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.yaml
printf "\n### Waiting for cert-manager to become ready... ###\n"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n cert-manager --timeout=5m
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=cainjector -n cert-manager --timeout=5m
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=webhook -n cert-manager --timeout=5m
printf "\n### Cert-Manager Helm release installed successfully! ###\n"

# Install OpenTelemetry
printf "\n### Adding OpenTelemetry Helm repository... ###\n"
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
printf "\n### Installing OpenTelemetry Operator in the otel namespace... ###\n"
helm upgrade --install otel open-telemetry/opentelemetry-operator -n otel --create-namespace --set-json='manager.featureGates="operator.autoinstrumentation.multi-instrumentation,operator.autoinstrumentation.go,operator.autoinstrumentation.nginx"'
printf "\n### Waiting for OpenTelemetry Operator to become ready... ###\n"
printf "\n### This can take a while, please be patient until you see further output... ###\n"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=opentelemetry-operator -n otel --timeout=5m
printf "\n### OpenTelemetry Operator Helm Chart installed successfully in the otel namespace"
printf "\n### Installing our own custom OpenTelemetry components in the otel namespace ###\n"
kubectl apply -f otel-components.yaml -n otel
printf "\n### OpenTelemetry components (Gateway Collector / Instrumentation) installed successfully in the otel namespace ###\n"

# Install OnlineBoutique
printf "\n### Installing Online Boutique application in the boutique namespace... ###\n"
helm upgrade --install boutique oci://us-docker.pkg.dev/online-boutique-ci/charts/onlineboutique -n boutique --create-namespace
printf "\n### Waiting for Online Boutique application to become ready... ###\n"
kubectl wait --for=condition=ready pod -l app=frontend -n boutique --timeout=5m
printf "\n### Online Boutique application installed successfully in the boutique namespace ###\n"

# Patch pod annotations
printf "\n### Automatically patching Boutique pod annotations to support auto-instrumentation ###\n"
kubectl patch deployment -n boutique emailservice -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python": "otel/instrumentation"}}}}}'
kubectl patch deployment -n boutique loadgenerator -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python": "otel/instrumentation"}}}}}'
kubectl patch deployment -n boutique recommendationservice -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-python": "otel/instrumentation"}}}}}'
kubectl patch deployment -n boutique cartservice -p '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-dotnet": "otel/instrumentation"}}}}}'

kubectl patch deployment -n boutique frontend --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": [SYS_PTRACE]},
    {"op": "add", "path": "/spec/template/metadata/annotations", "value": {
        "instrumentation.opentelemetry.io/inject-go": "otel/instrumentation",
        "instrumentation.opentelemetry.io/otel-go-auto-target-exe": "/src/server"
        }
    }
]'

kubectl patch deployment -n boutique productcatalogservice --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": [SYS_PTRACE]},
    {"op": "add", "path": "/spec/template/metadata/annotations", "value": {
        "instrumentation.opentelemetry.io/inject-go": "otel/instrumentation",
        "instrumentation.opentelemetry.io/otel-go-auto-target-exe": "/src/server"
        }
    }
]'

kubectl patch deployment -n boutique shippingservice --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": [SYS_PTRACE]},
    {"op": "add", "path": "/spec/template/metadata/annotations", "value": {
        "instrumentation.opentelemetry.io/inject-go": "otel/instrumentation",
        "instrumentation.opentelemetry.io/otel-go-auto-target-exe": "/src/shippingservice"
        }
    }
]'

kubectl patch deployment -n boutique checkoutservice --type='json' -p='[
    {"op": "add", "path": "/spec/template/spec/containers/0/securityContext/capabilities/add", "value": [SYS_PTRACE]},
    {"op": "add", "path": "/spec/template/metadata/annotations", "value": {
        "instrumentation.opentelemetry.io/inject-go": "otel/instrumentation",
        "instrumentation.opentelemetry.io/otel-go-auto-target-exe": "/src/checkoutservice"
        }
    }
]'

printf "\n### Script execution finished ###\n"