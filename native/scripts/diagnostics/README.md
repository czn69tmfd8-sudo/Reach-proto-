# Linux dispatch runtime investigation

These opt-in diagnostic sources do not import REACH, XCTest, Firebase or WebRTC.
They do not patch the toolchain or change any test pass/fail decision.

On the Work Linux environment, Swift 6.0.3 `linux-dispatch-probe.swift` reproduced
SIGILL using four global-queue jobs and a 500ms wait. Loader mappings plus offline
objdump/addr2line locate the trap in libdispatch at offset 0x212f0:
`_dispatch_workq_monitor_pools.cold.1`. Its branch follows open(`/proc/<tid>/stat`,
O_RDONLY | O_NONBLOCK) returning -1. Swift's crash report also contains this path.

An independent C pthread probe (`linux-thread-proc.c`) reported getpid=2,
gettid=11, with both `/proc/11/stat` and `/proc/self/task/11/stat` returning
fd=-1, errno=2 (ENOENT), while the worker was still alive. IDs vary per run.
This establishes missing live-worker proc visibility here; it does not establish
which hosting/virtualization component is responsible. Do not infer that GitHub
Ubuntu runners or iOS have the same problem.

Reproduction commands for a developer on Linux (use existing local toolchains):

```sh
cc -pthread native/scripts/diagnostics/linux-thread-proc.c -o /tmp/reach-thread-proc
/tmp/reach-thread-proc
swiftc -swift-version 5 native/scripts/diagnostics/linux-dispatch-probe.swift -o /tmp/reach-dispatch-probe
/tmp/reach-dispatch-probe
```

The full portable suite can still finish before the monitor hits the missing
entry: this session's single full run passed 112/112 tests in 0.736 seconds.
A passing run does not resolve the separately reproduced environment failure.
The portable runner's `REACH_PORTABLE_LOADER_TRACE=1` option retains mappings
on failures; it never retries or suppresses a crash. Keep macOS CI as the iOS gate.

Upstream source inspected: swift-corelibs-libdispatch, swift-6.0.3-RELEASE,
`src/event/workqueue.c`, `_dispatch_workq_count_runnable_workers` (open failure
calls DISPATCH_CLIENT_CRASH with "registered worker exited prematurely").
