# Reverse Proxy Configuration Patterns

## Caddy

Caddy's killer feature is automatic HTTPS via ACME (Let's Encrypt / ZeroSSL). Minimal config,
sane defaults, JSON API for programmatic control.

### Basic reverse proxy

```
# Caddyfile
app.example.com {
  reverse_proxy localhost:8080
}

# Multiple upstreams with health checks
api.example.com {
  reverse_proxy localhost:8081 localhost:8082 {
    health_uri /health
    health_interval 10s
    health_timeout 5s
    lb_policy round_robin
  }
}
```

### WebSocket proxying

```
ws.example.com {
  reverse_proxy localhost:8090
  # WebSocket works automatically -- Caddy handles Upgrade headers
}
```

### gRPC proxying

```
grpc.example.com {
  reverse_proxy h2c://localhost:50051
  # h2c = HTTP/2 cleartext (gRPC without TLS to backend)
}
```

### Rate limiting

```
api.example.com {
  rate_limit {
    zone api_limit {
      key {remote_host}
      events 100
      window 1m
    }
  }
  reverse_proxy localhost:8080
}
```

### On-demand TLS (wildcard without DNS challenge)

```
{
  on_demand_tls {
    ask http://localhost:5555/check   # Backend validates the domain
  }
}

https:// {
  tls {
    on_demand
  }
  reverse_proxy localhost:8080
}
```

### Internal TLS (self-signed for internal services)

```
app.internal:443 {
  tls internal     # Auto-generates self-signed cert from Caddy's internal CA
  reverse_proxy localhost:8080
}
```

### Validation and reload

```bash
caddy validate --config /etc/caddy/Caddyfile
caddy reload --config /etc/caddy/Caddyfile
# Or via API: curl localhost:2019/load -H "Content-Type: text/caddyfile" --data-binary @Caddyfile
```

---

## Nginx

High-performance, battle-tested. Best for static file serving + high-traffic reverse proxy.

### Basic reverse proxy

```nginx
upstream backend {
    server 127.0.0.1:8080;
    server 127.0.0.1:8081;
    keepalive 32;    # connection pooling to upstreams
}

server {
    listen 443 ssl;
    server_name app.example.com;

    ssl_certificate /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Connection "";    # enable keepalive to upstream
    }
}
```

### WebSocket proxying

```nginx
location /ws {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 86400;    # keep WebSocket alive
}
```

### L4 (TCP/UDP) proxying -- stream module

```nginx
stream {
    upstream postgres {
        server 10.0.1.50:5432;
        server 10.0.1.51:5432;
    }
    server {
        listen 5432;
        proxy_pass postgres;
        proxy_timeout 300s;
    }
}
```

### Rate limiting

```nginx
http {
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    server {
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://backend;
        }
    }
}
```

### Security headers

```nginx
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "DENY" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'" always;
```

### Validation and reload

```bash
nginx -t                          # syntax check
nginx -s reload                   # graceful reload
# Or: systemctl reload nginx
```

---

## Traefik

Best for Docker/K8s environments with dynamic service discovery.

### Docker Compose labels (most common pattern)

```yaml
services:
  app:
    image: myapp:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.app.rule=Host(`app.example.com`)"
      - "traefik.http.routers.app.tls.certresolver=letsencrypt"
      - "traefik.http.services.app.loadbalancer.server.port=8080"

  traefik:
    image: traefik:v3.6
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/acme/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - acme:/acme
```

### Middleware chains

```yaml
labels:
  # Rate limiting
  - "traefik.http.middlewares.ratelimit.ratelimit.average=100"
  - "traefik.http.middlewares.ratelimit.ratelimit.burst=50"
  # IP whitelist
  - "traefik.http.middlewares.internal.ipallowlist.sourcerange=10.0.0.0/8"
  # Chain them
  - "traefik.http.routers.app.middlewares=ratelimit@docker,internal@docker"
```

### File provider (non-Docker)

```yaml
# /etc/traefik/traefik.yml
entryPoints:
  web: { address: ":80" }
  websecure: { address: ":443" }
providers:
  file:
    directory: /etc/traefik/conf.d/
    watch: true

# /etc/traefik/conf.d/app.yml
http:
  routers:
    app:
      rule: "Host(`app.example.com`)"
      service: app
      tls:
        certResolver: letsencrypt
  services:
    app:
      loadBalancer:
        servers:
          - url: "http://10.0.1.50:8080"
          - url: "http://10.0.1.51:8080"
        healthCheck:
          path: /health
          interval: 10s
```

---

## HAProxy

Pure load balancer. Best for L4/L7 performance, stick tables, advanced ACLs.

### Basic L7 reverse proxy

```
global
    log stdout format raw local0
    maxconn 4096

defaults
    mode http
    log global
    option httplog
    option dontlognull
    timeout connect 5s
    timeout client 30s
    timeout server 30s
    retry-on all-retryable-errors

frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/haproxy/certs/
    http-request redirect scheme https unless { ssl_fc }
    default_backend http_back

backend http_back
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200
    server app1 10.0.1.50:8080 check inter 5s fall 3 rise 2
    server app2 10.0.1.51:8080 check inter 5s fall 3 rise 2
```

### L4 (TCP) load balancing

```
frontend tcp_front
    mode tcp
    bind *:5432
    default_backend postgres_back

backend postgres_back
    mode tcp
    balance leastconn
    option tcp-check
    server pg1 10.0.1.50:5432 check inter 5s
    server pg2 10.0.1.51:5432 check inter 5s backup
```

### Stick tables (rate limiting, session persistence)

```
frontend http_front
    bind *:443 ssl crt /etc/haproxy/certs/
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
```

### Stats page

```
frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST
```

### Validation

```bash
haproxy -c -f /etc/haproxy/haproxy.cfg    # config check
haproxy -f /etc/haproxy/haproxy.cfg -sf $(pidof haproxy)  # graceful reload
# Or: systemctl reload haproxy
```

---

## Common Patterns

### HTTP to HTTPS redirect

| Proxy | Pattern |
|-------|---------|
| Caddy | Automatic (default behavior) |
| Nginx | `return 301 https://$host$request_uri;` in port 80 server block |
| Traefik | `--entrypoints.web.http.redirections.entryPoint.to=websecure` |
| HAProxy | `http-request redirect scheme https unless { ssl_fc }` |

### Health checks

All proxies should health-check backends. Without health checks, traffic goes to dead backends
until the proxy's TCP timeout expires (often 30s+ of failed requests).

### Request smuggling prevention

```nginx
# Nginx: reject ambiguous requests
proxy_http_version 1.1;
proxy_set_header Connection "";
# Disable chunked encoding manipulation
proxy_request_buffering on;
```

```
# HAProxy: strict HTTP parsing
global
    tune.h2.header-table-size 4096
defaults
    option http-use-htx
    http-request deny if { req.hdr_cnt(content-length) gt 1 }
    http-request deny if { req.hdr_cnt(transfer-encoding) gt 1 }
```

### mTLS (mutual TLS to backend)

**Breaking change (2025-2027):** public CAs are removing the Client Authentication EKU from
TLS certificates. By Feb 2027, public CA certs won't work for mTLS. Use a **private CA**
(step-ca, cfssl, Vault PKI, OpenSSL) for all mTLS client certificates.

```nginx
# Nginx
location / {
    proxy_pass https://backend;
    proxy_ssl_certificate /etc/nginx/client.crt;
    proxy_ssl_certificate_key /etc/nginx/client.key;
    proxy_ssl_trusted_certificate /etc/nginx/ca.crt;
    proxy_ssl_verify on;
}
```

```
# Caddy
reverse_proxy https://backend:8443 {
    transport http {
        tls_client_auth /path/to/client.crt /path/to/client.key
        tls_trusted_ca_certs /path/to/ca.crt
    }
}
```
