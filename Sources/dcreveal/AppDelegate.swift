import Cocoa
import os

let logger = Logger(subsystem: "com.moridonut.dcreveal", category: "event")

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 起動のきっかけになったイベント（未起動時に届いた reveal）を取りこぼさず、
    /// かつ AppKit 既定の odoc ハンドラを上書きするため、willFinishLaunching で登録する。
    func applicationWillFinishLaunching(_ notification: Notification) {
        let manager = NSAppleEventManager.shared()
        let selector = #selector(handle(_:withReply:))

        // NSWorkspace が NSFileViewer 宛てに送るのは、Finder と同じ「reveal」('misc'/'mvis')と見込んでいる。
        manager.setEventHandler(self, andSelector: selector,
                                forEventClass: AEEventClass(kAEMiscStandards),
                                andEventID: AEEventID(kAEMakeObjectsVisible))
        // 送り元によっては「開く」(odoc) で来る可能性もあるので同じ処理で受ける。
        manager.setEventHandler(self, andSelector: selector,
                                forEventClass: AEEventClass(kCoreEventClass),
                                andEventID: AEEventID(kAEOpenDocuments))
        // それ以外は全部ここに落ちる。届いたイベントの種類を確かめるための観測窓。
        // AE の振り分けは完全一致が優先なので、AppKit の quit/oapp などは奪わない。
        manager.setEventHandler(self, andSelector: selector,
                                forEventClass: AEEventClass(typeWildCard),
                                andEventID: AEEventID(typeWildCard))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("dcreveal started")
    }

    @objc func handle(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        let senderPID = event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value ?? 0
        let senderName = senderPID > 0
            ? (NSRunningApplication(processIdentifier: senderPID)?.localizedName ?? "pid \(senderPID)")
            : "unknown"
        logger.info("event \(event.eventClass.fourCC, privacy: .public)/\(event.eventID.fourCC, privacy: .public) from \(senderName, privacy: .public)")

        let urls = FileURLExtractor.urls(from: event)
        guard !urls.isEmpty else {
            // パスを持たないイベント（あるいは取り出せない形式）。中身をログに残して何もしない。
            logger.info("no file URL in event: \(event.description, privacy: .public)")
            return
        }

        let config = Config.load()

        // ループ防止: DC 自身（DC から起動された `open -R` なども含む）からの「Finder に表示」は
        // 本当に Finder を開きたいときなので、DC に戻さず Finder に渡す。
        if senderPID > 0, ProcessTree.isDescendant(of: config.dcBundleID, pid: senderPID) {
            logger.info("request came from Double Commander; forwarding to Finder")
            Forwarder.revealInFinder(urls)
            return
        }

        Forwarder.revealInDoubleCommander(urls, config: config)
    }
}

extension FourCharCode {
    /// 'mvis' のような4文字コードをログ用の文字列に戻す
    var fourCC: String {
        let bytes = [24, 16, 8, 0].map { UInt8((self >> $0) & 0xff) }
        return String(bytes: bytes, encoding: .macOSRoman) ?? String(self)
    }
}
