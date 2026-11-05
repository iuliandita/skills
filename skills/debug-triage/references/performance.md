# Performance diagnosis

## Workflow

Copy and track; each step depends on the previous one:
- [ ] 1. Symptom and reproducible baseline captured
- [ ] 2. Hypotheses ranked; discriminating profile chosen
- [ ] 3. Profile captured safely during the symptom
- [ ] 4. One causal factor changed
- [ ] 5. Result measured on the same workload (if it does not improve or a user-facing metric regresses, return to Step 2)

### 1. Define the symptom and baseline

State the operation, input shape, environment, concurrency, warm-up, measurement window, and success
metric. Capture at least throughput plus latency percentiles, error rate, and resource use. Keep the
baseline workload and environment reproducible; compare like with like, including cache state and
data volume. A single elapsed-time run is a hypothesis, not a regression result.

### 2. Form and rank hypotheses

Use the baseline to separate CPU saturation, allocation/GC pressure, heap retention, lock wait,
I/O wait, queueing, and downstream latency. Choose the smallest discriminating profile or trace:
CPU profile for hot compute, allocation profile for allocation rate, heap snapshot for retained
objects, mutex/lock profile for contention, and a trace or dependency timing for waits outside the
process. Capture a profile during the symptom, not only when idle. See the profiler table below for runtime-specific starting points.

### 3. Capture safely

Use bounded duration, production-safe sampling, and scrub or avoid sensitive request payloads. Keep
the raw profile, workload revision, runtime/build version, and command/configuration needed to repeat
it. Avoid enabling high-overhead instrumentation across a fleet during an incident; sample one
representative instance or reproduce outside production first.

### 4. Change one causal factor

Explain why the profile supports the proposed change, then alter one factor. Do not optimize a
function solely because it is visible in a flame graph: inclusive CPU includes time in callees,
and allocation hotness may be harmless unless it drives GC or memory pressure. Preserve correctness
and track any tradeoff such as memory for CPU or tail latency for throughput.

### 5. Measure the result and guard it

Repeat the same workload after warm-up. Report sample count, median and tail latency, throughput,
errors, CPU, allocation/heap, and the variance or confidence limits available from the runner.
Keep or add a small representative regression benchmark when the project has a benchmark convention;
otherwise record the reproducible command and baseline artifact. When a meaningful user-facing
metric regresses, even if a microbenchmark improves, roll back the change and return to Step 2.


# Profilers by Runtime

Pick the tool that matches the runtime and the profile type chosen in Workflow step 2. None of
these ship with a base OS: detect the tool first (`command -v perf`, `command -v py-spy`, ...) and
check flags with `--help` before running against production.

| Runtime / target | Profile type | Tool | Representative command |
|---|---|---|---|
| Linux (any compiled/native process) | CPU | perf | `perf record -g -p <pid> -- sleep 30` then `perf report` |
| Go | CPU | pprof (net/http/pprof) | `go tool pprof -http=: 'http://host/debug/pprof/profile?seconds=30'` |
| Go | heap | pprof | `go tool pprof -http=: 'http://host/debug/pprof/heap'` |
| Python | CPU | py-spy | `py-spy record -d 30 -o out.svg --pid <pid>` |
| JVM | CPU/allocation | async-profiler | `asprof -d 30 -f out.html <pid>` |
| .NET | CPU/general trace | dotnet-trace | `dotnet-trace collect -p <pid> --duration 00:00:00:30` |
| Node.js | CPU | node --cpu-prof | `node --cpu-prof --cpu-prof-dir=. app.js` |
| Native (C/C++/Rust) | heap/allocation | heaptrack (default) | `heaptrack ./binary` |
| Native (C/C++/Rust) | heap/allocation | valgrind massif (fallback) | `valgrind --tool=massif ./binary` |

Notes:

- `perf` needs `CAP_PERFMON` or root, and `kernel.perf_event_paranoid` may need lowering; bound
  capture duration with `-- sleep <seconds>` or a fixed run instead of an open-ended `perf record`.
- Go pprof profiles pull from a running `net/http/pprof`-enabled process; `seconds=30` bounds the
  capture window. Use `go tool pprof -http=: <binary> <profile-file>` for an offline profile file.
- py-spy attaches without code changes; on Linux it needs `ptrace` permission (`--pid` may require
  running as the same user or with elevated capability).
- async-profiler's `asprof` CLI attaches to a running JVM by PID; output format is chosen by the
  target file extension (`.html`, `.collapsed`, `.jfr`).
- `dotnet-trace collect` writes a `.nettrace` file; convert or view with `dotnet-trace` or
  PerfView/`speedscope` as needed.
- `node --cpu-prof` writes a `.cpuprofile` file on process exit (or `SIGINT`); open it in Chrome
  DevTools or a `.cpuprofile` viewer.
- heaptrack can also attach to a running process (`heaptrack --pid <pid>`), but only tracks
  allocations made after attaching. Use massif when heaptrack is unavailable; it requires
  re-running the target under the tool, so reproduce the workload while it runs.
