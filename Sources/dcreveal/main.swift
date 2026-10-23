import Cocoa

// dcreveal: macOS の「Finder に表示」を Double Commander に流す受け口アプリ。
// 設計の全体像は README.md を参照。

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Info.plist の LSUIElement と同じ意味。Dock にもアプリ切替にも出さない。
app.setActivationPolicy(.accessory)
app.run()
