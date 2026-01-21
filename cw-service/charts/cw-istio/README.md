# Istio Resources Subchart

This subchart manages Istio service mesh resources for the parent `cw-service` chart.

## Resources

- **VirtualService**: Traffic routing rules
- **DestinationRule**: Load balancing, circuit breaking, and service subsets
- **Gateway**: Ingress traffic management
- **PeerAuthentication**: mTLS configuration

## Usage

Enable Istio resources in your values file:

```yaml
cw-istio:
  enabled: true
  service:
    name: myapp-prod-us-east-1  # Auto-populated from parent
    port: 80                     # Auto-populated from parent
  
  virtualService:
    enabled: true
    hosts:
      - myapp.example.com
    gateways:
      - istio-system/main-gateway
  
  destinationRule:
    enabled: true
    trafficPolicy:
      loadBalancer:
        simple: LEAST_CONN
```

The service name and port are automatically inherited from the parent chart.
