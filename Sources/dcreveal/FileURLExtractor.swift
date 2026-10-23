import Cocoa

/// Apple Event の直接目的語からファイルの URL を取り出す。
/// 送り元によって、alias / fileURL / 文字列 / それらのリスト、と形がまちまちなので全部試す。
enum FileURLExtractor {
    static func urls(from event: NSAppleEventDescriptor) -> [URL] {
        guard let direct = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return [] }
        let items: [NSAppleEventDescriptor]
        if direct.numberOfItems > 0 {
            items = (1...direct.numberOfItems).compactMap { direct.atIndex($0) }
        } else {
            items = [direct]
        }
        return items.compactMap(url(from:))
    }

    private static func url(from d: NSAppleEventDescriptor) -> URL? {
        // alias / bookmark / furl など、システムが変換できるものはこれで取れる
        if let u = d.fileURLValue { return u }
        if let data = d.coerce(toDescriptorType: DescType(typeFileURL))?.data,
           let s = String(data: data, encoding: .utf8),
           let u = URL(string: s), u.isFileURL {
            return u
        }
        // 文字列で来た場合（"file://..." でも "/Users/..." でも受ける）
        if let s = d.stringValue {
            if s.hasPrefix("file://"), let u = URL(string: s) { return u }
            if s.hasPrefix("/") { return URL(fileURLWithPath: s) }
        }
        return nil
    }
}
