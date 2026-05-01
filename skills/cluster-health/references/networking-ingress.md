# Networking and Ingress

## Purpose

Check services, ingress, load balancers, DNS, and certificates using read-only commands.

## Commands

```bash
kubectl --context <context> get svc -A -o wide | head -n 120
kubectl --context <context> get ingress -A -o wide | head -n 120
kubectl --context <context> describe ingress -n <namespace> <ingress> | tail -n 120
kubectl --context <context> get endpointslices -A | head -n 120
kubectl --context <context> get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -n 80
dig +short <hostname> 2>/dev/null || true
echo | openssl s_client -servername <hostname> -connect <hostname>:443 2>/dev/null | openssl x509 -noout -dates -issuer -subject
```

## Criteria

- GREEN: services have endpoints, ingress addresses exist, DNS resolves, certificates are valid.
- YELLOW: one ingress missing address, stale endpoint on non-critical service, certificate near expiry.
- RED: no endpoints for a critical service, DNS failure, expired certificate, or load balancer absent.

## Common False Positives

- Headless services intentionally have no load balancer.
- Internal-only hostnames may not resolve from the current network.
- Certificate checks fail when split-horizon DNS requires running from inside the network.

## Output Caps

Use `head -n 120` for broad lists and `describe` only the suspect ingress, service, or endpoint.
