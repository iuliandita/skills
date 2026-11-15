# Load Testing

k6 detection and a starter script with thresholds.

## Load testing (k6)

Detect first: `command -v k6 >/dev/null || echo "k6 missing"`.

```javascript
// k6 load test
import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  stages: [
    { duration: "30s", target: 50 },   // ramp up
    { duration: "1m",  target: 50 },   // sustain
    { duration: "10s", target: 0 },    // ramp down
  ],
  thresholds: {
    checks: ["rate==1"],              // fail the run when any status check fails
    http_req_duration: ["p(95)<500"],   // 95th percentile under 500ms
  },
};

export default function () {
  const res = http.get("http://localhost:3000/api/health");
  check(res, { "status 200": (r) => r.status === 200 });
  sleep(1);
}
```
