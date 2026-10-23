import Cocoa

/// 設定は `defaults write com.moridonut.dcreveal <Key> <Value>` で変える。
/// イベントごとに読み直すので、変更にアプリの再起動は要らない。
struct Config {
    /// Double Commander の bundle identifier（実機確認済みの値。`org.doublecmd.doublecmd` ではない）
    var dcBundleID: String
    /// bundle ID で見つからなかったときの .app のパス
    var dcAppPath: String
    /// 開くパネル。"L" か "R"
    var side: String
    /// true: 新しいタブで開く / false: そのパネルの現在タブを置き換える
    var newTab: Bool
    /// true: ファイルは親フォルダを開く（DC がファイルにカーソルを合わせない場合の逃げ道）
    var revealParent: Bool

    static func load() -> Config {
        let d = UserDefaults.standard
        let side = (d.string(forKey: "Side") ?? "L").uppercased()
        return Config(
            dcBundleID: d.string(forKey: "DCBundleID") ?? "com.company.doublecmd",
            dcAppPath: d.string(forKey: "DCAppPath") ?? "/Applications/Double Commander.app",
            side: side == "R" ? "R" : "L",
            newTab: d.object(forKey: "NewTab") as? Bool ?? true,
            revealParent: d.bool(forKey: "RevealParent")
        )
    }
}
