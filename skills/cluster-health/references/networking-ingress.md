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
dig +short <hostname> 2>&1 || true
echo | openssl s_client -servername <hostname> -connect <hostname>:443 2>&1 | openssl x509 -noout -dates -issuer -subject 2>&1
```

Surface the DNS and TLS error, do not swallow it. `dig ... 2>/dev/null` and
`openssl ... 2>/dev/null` turn "DNS server unreachable" and "connection refused" into the same blank
output as "name does not exist," which reads as a clean check. Keep `2>&1` and read the message:

| Symptom | Means | Not |
|---------|-------|-----|
| `dig` empty + `SERVFAIL`/`connection timed out` | resolver unreachable from here | "hostname is down" |
| `dig` empty, `NXDOMAIN` | record genuinely absent or internal-only name from outside | resolver failure |
| `openssl` `connect: Connection refused` | nothing listening on 443 | expired cert |
| `openssl` `verify error: certificate has expired` | actual expiry | unreachable |

## Status interpretation

- **Endpoints, not just the Service object.** A Service can exist with zero ready endpoints
  (`get endpointslices` shows none, or `describe svc` shows `Endpoints: <none>`). The Service object
  being present is not proof traffic flows; an empty endpoint set means the selector matches no
  ready pod. That is the signal for a "Service up but 503" situation.
- **Ingress `ADDRESS` column.** An ingress with no `ADDRESS` means the controller has not assigned
  one - controller not running, no matching ingressClass, or a pending LoadBalancer. Absent address
  is "not wired up," not "wired and healthy."
- **LoadBalancer `EXTERNAL-IP` `<pending>`.** The cloud provider has not provisioned the LB yet (or
  there is no cloud controller, common on bare metal without MetalLB). Pending is a provisioning
  state, not a transient blip to ignore if it persists.
- **Certificate dates are a calculation, not a status.** `openssl x509 -dates` prints `notAfter`;
  judge expiry against now and against the renewal lead time (cert-manager typically renews well
  before expiry). A cert valid for two more days under a daily renewal loop that has stalled is a
  RED-trending finding even though it has not expired yet.

## Schedule-aware staleness

cert-manager and ACME renewals run on a cadence and renew ahead of `notAfter`. Compare the cert's
remaining validity against the renewal lead time, not against zero. A cert that should have renewed
3 days ago but did not is a stalled-renewal finding even with validity left. Check the renewal
controller, not only the expiry date.

## Criteria

- GREEN: services have ready endpoints, ingress addresses assigned, DNS resolves, certificates valid with renewal headroom.
- YELLOW: one ingress missing address, stale endpoint on a non-critical service, certificate inside renewal window but not yet renewed, LoadBalancer pending on a non-critical service.
- RED: no endpoints for a critical service, DNS resolution failure (not just internal-only name), expired certificate, stalled renewal, or load balancer never provisioned for a critical path.

## Common False Positives

- Headless services intentionally have no load balancer or cluster IP.
- Internal-only hostnames may not resolve from the current network (NXDOMAIN from outside is not failure).
- Certificate checks fail when split-horizon DNS requires running from inside the network.
- A `<pending>` LoadBalancer on bare metal with no LB implementation is config, not an outage.

## Output Caps

Use `head -n 120` for broad lists and `describe` only the suspect ingress, service, or endpoint.
