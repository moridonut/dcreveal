# dcreveal

macOS の各アプリにある「Finder に表示 / Reveal in Finder / Show in Finder」を横取りして、
[Double Commander](https://doublecmd.sourceforge.io/)（以下 DC）で開く小さな常駐アプリ。

```
各アプリの「Finder に表示」
   → NSWorkspace（NSFileViewer を参照）
   → dcreveal
   → doublecmd -C -T -P L -L <パス>
```

## なぜ作ったか

Windows で「あふ」を使っていた頃は、どのアプリから「フォルダを開く」をしても自分のファイラーに来ていた。
Mac に移って DC をメインにしたが、Chrome のダウンロード、VS Code、Slack などの「Finder に表示」は
全部 Finder に飛んでしまい、そこから改めて DC で開き直す手間が残っていた。

macOS には「既定のファイルマネージャ」を選ぶ設定項目は無い。ただし隠し設定 `NSFileViewer` があり、
ForkLift や Path Finder はこれで「既定のファイルビューア」になっている。dcreveal はこの仕組みに乗る。

## 設計

### 1. `NSFileViewer` に乗る（キー・メニューの横取りはしない）

多くのアプリの「Finder に表示」は、自前で Finder を操作しているのではなく
`NSWorkspace.activateFileViewerSelectingURLs` / `selectFile(_:inFileViewerRootedAtPath:)` を呼んでいるだけ。
Electron の `shell.showItemInFolder` もこれを使う。
このAPIはグローバル設定 `NSFileViewer` に書かれた bundle ID のアプリへ「表示して」という Apple Event を送る。

つまり、送り先を1か所差し替えるだけで、個々のアプリに手を入れずに大部分をまとめて拾える。
Karabiner でキーを、BetterTouchTool で右クリックメニューを足すやり方は、アプリごとに対応が要るので採らなかった。

### 2. DC を直接指定せず、間に受け口アプリを挟む

`NSFileViewer` に DC の bundle ID（`com.company.doublecmd`）を直接書くこともできるが、
DC は Lazarus 製で、Finder 互換の「reveal」Apple Event を処理しない。
直接指定すると DC が前面に来るだけで、目的のパスには移動しない（と見込んだ）。

そこで Apple Event をネイティブに受けられる小さな Swift アプリを用意し、
受け取ったパスを DC のコマンドライン（`-C` で起動中のインスタンスへ転送）に変換する。
引数は Finder 連携（BTT）・`dc-mdfind.sh` と同じ `-C -T -P <side> -<side> <path>` に揃えている。

### 3. どのイベントが来るか分からない前提で作る

NSWorkspace が `NSFileViewer` 宛てに送るイベントの種類は公式には書かれていない。
Finder の reveal（`misc`/`mvis`）が本命だが、送り元によっては「開く」（`aevt`/`odoc`）の可能性もある。
そのため:

- `misc/mvis` と `aevt/odoc` を同じ処理で受ける
- それ以外は**ワイルドカードで全部受けてログに出す**（AppKit の quit などは完全一致が優先されるので奪わない）
- 直接目的語は alias / fileURL / 文字列 / それらのリスト、のどれで来ても URL に直す

`make log` で、どのアプリからどの種類のイベントが届いたかをその場で確認できる。

### 4. DC 自身からの「Finder に表示」は本物の Finder へ（ループ防止）

DC のツールバーには「Open in Finder」（`open -R %p`）ボタンがある。
`open -R` も同じ NSWorkspace の経路を通るので、そのままだと DC → dcreveal → DC と戻ってきてしまう。

Apple Event の送り元 PID を取り、そのプロセス、または親をたどって数世代以内に DC がいれば、
「本当に Finder で見たい」要求とみなして Finder に渡す。
送り元は DC ではなく `/usr/bin/open` になるので、親をたどるのが要点。
Finder へは `NSWorkspace` ではなく、Finder を名指しする AppleScript で頼む（NSWorkspace を使うと自分に戻ってくるため）。

### 5. 失敗したら Finder に落とす

DC が見つからない、起動に失敗した、などのときは黙って何もしないのではなく Finder で開く。
「Finder に表示」を押して何も起きない、という状態だけは避ける。

### 6. その他の判断

- **複数選択は先頭だけ**: DC は1パネルに1パスしか受け取れないため。
- **ファイルはそのままのパスを渡す**: DC がそのファイルにカーソルを合わせる。合わない環境では `RevealParent` で親フォルダを開く方式に切り替えられる。
- **DC が未起動なら LaunchServices 経由で起動**: dcreveal の子プロセスにしないため。
- **`LANG` を補う**: GUI から起動されたプロセスには `LANG` が無い。dcreveal が DC を起動すると、DC から実行する外部コマンド（`pbcopy` など）まで UTF-8 でなくなり日本語が化けるので、`en_US.UTF-8` を補ってから渡す。
- **設定はイベントごとに読み直す**: `defaults write` の変更に再起動は要らない。
- **常駐エージェント（`LSUIElement`）**: Dock にもアプリ切り替えにも出ない。未起動でもイベントが来れば LaunchServices が起動するが、初回だけ少し遅れるのでログイン項目に入れておくのがよい。

## 拾えないもの

- AppleScript などで **Finder を名指し**して操作しているアプリ（`tell application "Finder" to reveal ...`）
- Finder 自身の操作、Spotlight など一部のシステム機能
- Dock のフォルダの「Finder に表示」は、ForkLift の利用者から効いたり効かなかったりするという報告がある

## 導入

前提: Xcode Command Line Tools（`swift`）、Double Commander が `/Applications` にあること。

```bash
make install   # build/dcreveal.app を作って ~/Applications に入れる
make enable    # defaults write -g NSFileViewer -string com.moridonut.dcreveal
# → ログアウトしてログインし直す
```

ログイン項目（システム設定 > 一般 > ログイン項目）に `~/Applications/dcreveal.app` を追加しておく。

動作確認:

```bash
make log                               # 別ターミナルで流しっぱなしにする
touch /tmp/dcreveal-test.txt
open -R /tmp/dcreveal-test.txt         # DC の左パネルで /tmp が開き、このファイルにカーソルが合えば OK
```

うまく行かないときは、まずアプリ単位で試す（グローバル設定を汚さずに済む）:

```bash
defaults write com.google.Chrome NSFileViewer -string com.moridonut.dcreveal
```

## 設定

| キー | 既定値 | 意味 |
|---|---|---|
| `Side` | `L` | 開くパネル（`L` / `R`） |
| `NewTab` | `true` | 新しいタブで開く。`false` で現在タブを置き換え |
| `RevealParent` | `false` | `true` でファイルは親フォルダを開く |
| `DCBundleID` | `com.company.doublecmd` | DC の bundle ID |
| `DCAppPath` | `/Applications/Double Commander.app` | bundle ID で見つからないときの場所 |

```bash
defaults write com.moridonut.dcreveal Side R
defaults write com.moridonut.dcreveal NewTab -bool false
```

## 元に戻す

```bash
make disable     # defaults delete -g NSFileViewer → ログアウト→ログイン
make uninstall
```

## 関連

- DC の「Open in Finder」ボタン（`open -R %p`）は、上記のループ防止によりそのまま Finder で開く。
  念のため Finder を名指しする形に変えておいてもよい:
  `osascript -e 'tell application "Finder" to reveal POSIX file "%p0"' -e 'tell application "Finder" to activate'`
- 初回の Finder フォールバック時に「dcreveal が Finder を制御」の許可ダイアログが出る（プライバシーとセキュリティ > オートメーション）。
