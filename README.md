# alt-ime-ahk-v2f

## 概要

左右 Alt キーの空打ちで IME を OFF/ON する AutoHotKey スクリプトです。

* 左 Alt キーの空打ちで IME を「英数」に切り替え
* 右 Alt キーの空打ちで IME を「かな」に切り替え
* Alt キーを押している間に他のキーを打つと通常の Alt キーとして動作
* CapsLock 無効化
* 文字列を選択後 Win + F で検索

## 修正
* Chrome や VS Code など Chromium 系アプリで、Alt 単押しで上部メニュー（右上「︙」など）にフォーカスが移るのを抑制
* Alt キーが押されたままになる不具合を修正。この状態では Esc が Alt+Esc（ウインドウ切替）に、Enter が Alt+Enter（全画面表示）になる。PC の起動直後など負荷が高いときに起きやすかった

## 動作環境

* Windows 10 / 11

## 使用方法

Releases から alt-ime-ahk-v2f.zip をダウンロード後、好きな場所へ解凍し、exe を起動するとタスクトレイに常駐します。

終了する場合はタスクトレイのアイコンを右クリックし、「終了」をクリックしてください。

アンインストールは alt-ime-ahk-v2f.exe を削除するだけで OK です。

## テスト

`tests\Test-AltStuck.ps1` は Alt キーが押されたままになる不具合の回帰テストです。スクリプトを起動して左右 Alt の素早いタップを注入し、タップのあとも Alt が押されたままになっていないかを確かめます。

```powershell
.\tests\Test-AltStuck.ps1 -AhkExe C:\path\to\AutoHotkey64.exe
```

* 実行の前に、常駐している alt-ime-ahk-v2f を終了してください。ほかのインスタンスが動いていると、テストは実行せずに終了します。
* テスト中は前面のウインドウに Alt が送られ、IME が切り替わります。終わるまで（既定で 4 分ほど）キーボードに触らないでください。
* 終了コードは、成功が 0、失敗が 1、実行できなかったときが 2 です。
* コンパイル済みの exe を試すときは、`-Script` に exe のパスを渡します（`-AhkExe` は不要）。

GitHub Actions（`.github/workflows/build.yml`）は、push のたびにこのテストを実行し、exe をビルドします。`v` で始まるタグ（例: `v1.0.2`）を push すると、exe とソース一式を入れた alt-ime-ahk-v2f.zip を添付したリリースを作ります。

## 参考

[Altの空打ちで日本語入力(IME)を切り替えるツールを作った](http://www.karakaram.com/alt-ime-on-off/)

[Autohotkey v2.0のIME制御用 関数群 IMEv2.ahk](https://qiita.com/kenichiro_ayaki/items/d55005df2787da725c6f)


## ライセンス

本ソフトウェアは GNU General Public License v2.0 (GPLv2) の下で配布されます。全文は [LICENSE](LICENSE) を参照してください。

Copyright (C) 2025-2026 ryo

本スクリプトは AutoHotkey（GPLv2）を利用しており、Ahk2Exe でコンパイルした exe には AutoHotkey インタプリタが含まれます。そのため exe のみを配布する場合でも、対応するソースコードは本リポジトリ [github.com/ryobeam/alt-ime-ahk-v2f](https://github.com/ryobeam/alt-ime-ahk-v2f) で公開しています。

なお、本スクリプトは karakaram 氏の alt-ime-ahk および IMEv2.ahk を基にしています（上記「参考」を参照）。
