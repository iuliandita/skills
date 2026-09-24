# Profilers by Runtime

Pick the tool that matches the runtime and the profile type chosen in Workflow step 2. These are
standard, widely used tools; verify installed versions and flags with `--help` before running
against production.

| Runtime / target | Profile type | Tool | Representative command |
|---|---|---|---|
| Linux (any compiled/native process) | CPU | perf | `perf record -g -p <pid>` then `perf report` |
| Go | CPU | pprof (net/http/pprof) | `go tool pprof -http=: http://host/debug/pprof/profile?seconds=30` |
| Go | heap | pprof | `go tool pprof -http=: http://host/debug/pprof/heap` |
| Python | CPU | py-spy | `py-spy record -o out.svg --pid <pid>` |
| JVM | CPU/allocation | async-profiler | `asprof -d 30 -f out.html <pid>` |
| .NET | CPU/general trace | dotnet-trace | `dotnet-trace collect -p <pid>` |
| Node.js | CPU | node --cpu-prof | `node --cpu-prof --cpu-prof-dir=. app.js` |
| Native (C/C++/Rust) | heap/allocation | valgrind massif | `valgrind --tool=massif ./binary` |
| Native (C/C++/Rust) | heap/allocation | heaptrack | `heaptrack ./binary` |

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
- massif requires re-running the target under the tool, so reproduce the workload while it runs.
  heaptrack can also attach to a running process (`heaptrack --pid <pid>`), but only tracks
  allocations made after attaching.
