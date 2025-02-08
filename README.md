# while-lsp

これは筑波大学の2025年2月の集中講義「ソフトウェアサイエンス特別講義A」のための教材です。

PHPのサブセットである構文を持っているWHILE言語と、そのためのLanguage server、VSCodeの拡張が含まれています。

## 使い方

Devcontainersの設定が含まれているので、VSCodeとDockerを用意すれば動かすことができます。

### リポジトリをcloneする

```sh
$ git clone https://github.com/soutaro/while-lsp.git
$ cd while-lsp
```

### Language serverの開発環境を起動する

```sh
# リポジトリのrootをVSCodeで開く
$ code .
```

VSCodeがDevcontainerで開くか？と聞いてくるので、開いてあげてください。
起動した後に、コマンドパレットから `Steep: Restart` として、型検査器を起動してください。

### Language serverの動作確認をする

```sh
# sampleディレクトリをvscodeで開く
$ code sample
```

VSCodeがDevcontainerで開くか？と聞いてくるので、開いてあげてください。
起動した後に、コマンドパレットから `WhileLSP: Start/restart langauge server` として、起動します

「ポートがlistenされている」という旨のメッセージが出ることがありました。
JSONやESLintなどのlanguage serverがなにかしているみたいです。
消し方がわかりませんでした。すみません……

### 開発の進め方

開発環境用と動作確認用の二つのVSCodeを同時に起動してください。
開発環境でプログラムを修正したら、動作確認用のVSCodeで `WhileLSP: Start/restart language server` コマンドを使ってLanguage serverを再起動します。
VSCodeの `OUTPUT` から、デバッグプリントを確認することができます。

## その他

* `vscode` ディレクトリにはVSCodeのExtensionが含まれています。講義では取り扱いません。
