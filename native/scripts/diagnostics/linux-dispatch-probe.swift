// Standalone Swift 6.0.3 Linux runtime reproduction; no REACH or XCTest dependency.
import Foundation
import Dispatch
import Glibc
@_silgen_name("gettid") func linuxThreadID() -> Int32
let group = DispatchGroup()
for _ in 0..<4 {
 group.enter()
 DispatchQueue.global().async {
  let tid=linuxThreadID()
  for path in ["/proc/\(tid)/stat", "/proc/self/task/\(tid)/stat"] {
   let fd=open(path,O_RDONLY|O_NONBLOCK)
   print("pid=\(getpid()) tid=\(tid) path=\(path) fd=\(fd) errno=\(fd < 0 ? errno : 0)")
   fflush(stdout)
   if fd >= 0 { close(fd) }
  }
  usleep(500_000)
  group.leave()
 }
}
group.wait()
