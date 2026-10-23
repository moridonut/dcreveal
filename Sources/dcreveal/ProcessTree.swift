import AppKit
import Darwin

/// 送り元プロセスが、指定アプリ自身またはその子孫かどうかを調べる。
/// DC のツールバーボタン `open -R %p` は、Apple Event の送り元が DC ではなく `/usr/bin/open` になるため、
/// 親をたどらないと「DC からの要求」だと判定できない。
enum ProcessTree {
    /// 何世代まで親をたどるか。DC → (bash) → open 程度を想定。
    private static let maxDepth = 4

    static func isDescendant(of bundleID: String, pid: pid_t) -> Bool {
        var current: pid_t? = pid
        for _ in 0..<maxDepth {
            guard let p = current else { return false }
            if NSRunningApplication(processIdentifier: p)?.bundleIdentifier == bundleID { return true }
            current = parentPID(of: p)
        }
        return false
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let ppid = info.kp_eproc.e_ppid
        // 1 (launchd) まで来たらそれ以上たどる意味はない
        return ppid > 1 ? ppid : nil
    }
}
