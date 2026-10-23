# dcreveal ビルド・導入用
#   make app      … build/dcreveal.app を作る
#   make install  … ~/Applications に入れて LaunchServices に登録
#   make enable   … NSFileViewer を dcreveal に向ける（要ログアウト→ログイン）
#   make disable  … NSFileViewer を消して Finder に戻す（要ログアウト→ログイン）
#   make log      … 届いたイベントをライブで見る

BUNDLE_ID  := com.moridonut.dcreveal
APP        := build/dcreveal.app
INSTALL_TO := $(HOME)/Applications/dcreveal.app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: build app install uninstall enable disable status log clean

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp .build/release/dcreveal $(APP)/Contents/MacOS/dcreveal
	# ad-hoc 署名。署名なしだとオートメーション許可（Finder へのフォールバック）が安定しない
	codesign --force --sign - $(APP)

install: app
	-osascript -e 'tell application id "$(BUNDLE_ID)" to quit' 2>/dev/null
	rm -rf $(INSTALL_TO)
	mkdir -p $(HOME)/Applications
	cp -R $(APP) $(INSTALL_TO)
	$(LSREGISTER) -f $(INSTALL_TO)
	@echo "installed: $(INSTALL_TO)"

uninstall:
	-osascript -e 'tell application id "$(BUNDLE_ID)" to quit' 2>/dev/null
	$(LSREGISTER) -u $(INSTALL_TO) || true
	rm -rf $(INSTALL_TO)

enable:
	defaults write -g NSFileViewer -string $(BUNDLE_ID)
	@echo "NSFileViewer = $(BUNDLE_ID)  → ログアウト→ログインで反映"

disable:
	defaults delete -g NSFileViewer || true
	@echo "NSFileViewer を削除（Finder に戻す）→ ログアウト→ログインで反映"

status:
	@printf "NSFileViewer: "; defaults read -g NSFileViewer 2>/dev/null || echo "(unset = Finder)"
	@defaults read $(BUNDLE_ID) 2>/dev/null || echo "dcreveal settings: (defaults)"

log:
	log stream --level info --predicate 'subsystem == "$(BUNDLE_ID)"'

clean:
	rm -rf .build build
