[← README に戻る](../README.md)

# サーバーの起動と停止

## 起動

先に Docker を起動しておきます。

### 1. DB を起動する（abr-batch のフォルダで）

```bash
cd ~/work/abr-batch
npm run db:up
```

すでに DB が動いていれば、この手順は不要です。Elasticsearch と Kibana も一緒に起動します。

Elasticsearch 検索（`/es`）を使うときは、インデックスを作っておきます（約 1 分）。DB の中身を変えたあとは、もう一度実行すると Elasticsearch に反映されます。

```bash
npm run es:index
```

### 2. アプリを起動する（abr-web-rails のフォルダで）

```bash
cd ~/work/abr-web-rails
bin/rails tailwindcss:build
bin/rails server
```

ブラウザで http://127.0.0.1:3000 を開きます。

- コードを保存すると、ブラウザを再読み込みするだけで反映されます（development モード）
- **画面の HTML に新しい Tailwind のクラスを書いたとき**は、`bin/rails tailwindcss:build` をもう一度実行するか、別のターミナルで `bin/rails tailwindcss:watch` を動かしておきます（保存するたびに CSS を作り直します）
- `bin/dev` を使うと、サーバーと `tailwindcss:watch` を 1 つのコマンドで動かせますが、初回は foreman（複数のプロセスをまとめて動かす道具）を `gem install` で入れます

## 停止

**自分のターミナルで起動した場合**：そのターミナルで **Ctrl + C** を押します。

**バックグラウンドで動いているものや、どこで動いているか分からない場合**：

```bash
kill $(cat tmp/pids/server.pid)
```

止まったかどうかは、次のコマンドで確かめます。何も表示されなければ止まっています。

```bash
ss -ltn | grep :3000
```

**DB も止めたい場合**（abr-batch のフォルダで）：

```bash
npm run db:down
```

DB を止めてもデータは消えません。

## 注意

- ほかの版（TypeScript・Laravel・Symfony・Spring Boot）も 3000 番ポートを使います。ほかの版が動いていると「Address already in use」で起動できないので、先に止めてください
- 前回のサーバーが正しく止まらなかったときは、`tmp/pids/server.pid` が残っていて「A server is already running」で起動できないことがあります。サーバーが動いていないことを確かめてから、このファイルを消してください
- DB が止まっていると、画面を開いたときに接続エラーになります
