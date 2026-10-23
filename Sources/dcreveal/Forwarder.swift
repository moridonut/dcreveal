import AppKit
import os

enum Forwarder {

    // MARK: - Double Commander

    static func revealInDoubleCommander(_ urls: [URL], config: Config) {
        // DC は1パネルに1パスしか受け取れない。複数指定されたら先頭だけ使う。
        guard let first = urls.first else { return }
        if urls.count > 1 {
            logger.info("\(urls.count) items requested; revealing only the first")
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir) else {
            logger.error("path does not exist: \(first.path, privacy: .public)")
            return
        }
        let target = (config.revealParent && !isDir.boolValue)
            ? first.deletingLastPathComponent().path
            : first.path

        guard let appURL = doubleCommanderURL(config) else {
            logger.error("Double Commander not found; falling back to Finder")
            revealInFinder(urls)
            return
        }

        // dc-mdfind.sh / BTT 連携と同じ引数体系に揃える
        var args = ["-C"]
        if config.newTab { args.append("-T") }
        args += ["-P", config.side, "-\(config.side)", target]
        logger.info("doublecmd \(args.joined(separator: " "), privacy: .public)")

        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: config.dcBundleID).first {
            // 起動中: `doublecmd -C` で既存インスタンスに渡す（-C が無いと転送されない）
            let p = Process()
            p.executableURL = appURL.appendingPathComponent("Contents/MacOS/doublecmd")
            p.arguments = args
            p.environment = environmentWithLocale()
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.terminationHandler = { _ in
                DispatchQueue.main.async { running.activate(options: []) }
            }
            do {
                try p.run()
            } catch {
                logger.error("failed to run doublecmd: \(error.localizedDescription, privacy: .public)")
                revealInFinder(urls)
            }
        } else {
            // 未起動: dcreveal の子プロセスにせず、LaunchServices 経由で普通のアプリとして起動する
            let conf = NSWorkspace.OpenConfiguration()
            conf.arguments = args
            conf.environment = environmentWithLocale()
            conf.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: conf) { _, error in
                if let error {
                    logger.error("failed to launch Double Commander: \(error.localizedDescription, privacy: .public)")
                    DispatchQueue.main.async { revealInFinder(urls) }
                }
            }
        }
    }

    private static func doubleCommanderURL(_ config: Config) -> URL? {
        if let u = NSWorkspace.shared.urlForApplication(withBundleIdentifier: config.dcBundleID) { return u }
        let u = URL(fileURLWithPath: config.dcAppPath)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    /// GUI から起動されたプロセスには LANG が入っていない。
    /// DC をここから起動すると、DC の外部コマンド（pbcopy など）まで UTF-8 でなくなり日本語が化けるので補う。
    private static func environmentWithLocale() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        if env["LC_CTYPE"] == nil { env["LC_CTYPE"] = "UTF-8" }
        return env
    }

    // MARK: - Finder（フォールバック・DC 自身からの要求）

    /// NSWorkspace.activateFileViewerSelectingURLs は NSFileViewer を見るので、ここで使うと自分に戻ってくる。
    /// Finder を名指しする AppleScript で直接頼む。
    static func revealInFinder(_ urls: [URL]) {
        let list = urls
            .map { "POSIX file \"\(escape($0.path))\"" }
            .joined(separator: ", ")
        let source = """
        tell application "Finder"
            reveal {\(list)}
            activate
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            logger.error("Finder reveal failed: \(error.description, privacy: .public)")
        }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
