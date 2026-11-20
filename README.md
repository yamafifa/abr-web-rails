# abr-web-rails

ABR（アドレス・ベース・レジストリ）の住居表示-住居マスター（`mt_rsdtdsp_rsdt`、東京都 1,752,573 件）を検索して、一覧表示・編集・削除する Web アプリです。
勉強用に、同じものを TypeScript・Ruby on Rails・PHP Laravel で作るうちの Ruby on Rails 版です。

- Ruby 3.4.5 ＋ Rails 8.1.4.1 ＋ Active Record ＋ Tailwind CSS 4 ＋ Turbo・Stimulus ＋ RSpec
- 構成は「Rails 標準の MVC ＋ ユースケース」（`app/usecases/`）。TS 版のユースケースと比べやすくしています
- DB は [abr-batch](https://github.com/yamafifa/abr-batch) の MySQL を共用します（テーブルも abr-batch で作ったもの）

## できること

TS 版と同じです。

- **検索**：市区町村（`city`・`ward`）、町字（`oaza_cho`・`koaza`）、丁目（`chome`）の部分一致と、`blk_num`・`rsdt_num` の完全一致。条件は URL に残ります
- **一覧**：主キー順。1 ページ 15 件（30・50・100 件も選べます）。ページャー付き
- **編集**：主キー以外の 17 列。「更新」を押すと、変わった項目をモーダルで見せてから保存します
- **削除**：一覧と編集画面から。モーダルで確認してから削除します

## 動かし方

1. abr-batch で DB を起動して、データを入れておく（abr-batch の README「動かし方」を参照）
2. このリポジトリで：

```bash
bundle config set --local path vendor/bundle   # gem をこのフォルダの中に入れる
bundle install
bin/rails tailwindcss:build
bin/rails server                                # http://127.0.0.1:3000
```

- 起動と停止の詳しいやり方は [docs/start-stop.md](docs/start-stop.md) にあります
- 編集・削除したデータは、abr-batch で `npm run import:v3`（約 15 秒）を実行すると元に戻せます
- **`bin/rails db:migrate` などの DB のタスクは使えません。** DB を abr-batch と共用しているので、[lib/tasks/db_guard.rake](lib/tasks/db_guard.rake) で止めています（`db:drop` で abr の DB が消える、`db:schema:load` でテーブルが空になる、などを防ぐため）

## 構成

| 場所 | 内容 |
|---|---|
| `app/models/rsdt.rb` | Active Record のモデル。複合主キー、17 列の入力チェック、空文字 → NULL、検索のスコープ、住所の表示 |
| `app/models/rsdt_search_criteria.rb` | 検索条件（`Data.define`） |
| `app/models/rsdt_list_query.rb` | 一覧の URL ⇔ 検索条件・件数・ページ |
| `app/usecases/` | ユースケース：`SearchRsdt`（ページ番号の補正もここ）・`GetRsdt`・`UpdateRsdt`・`DeleteRsdt` |
| `app/controllers/rsdts_controller.rb` | パラメーターを読む → ユースケースを呼ぶ → 表示・redirect |
| `app/controllers/concerns/back_url.rb` | 戻り先のチェック（外のサイトへ飛ばさない） |
| `app/helpers/pager_helper.rb` | ページャーに出すページ番号 |
| `app/views/rsdts/` | 一覧・編集・削除ボタン・検索フォーム・ページャー |
| `app/views/shared/` | 確認モーダル・お知らせ |
| `app/javascript/controllers/` | Stimulus：確認モーダル（`confirm`）、件数を変えたら検索（`auto_submit`）、お知らせを消す（`flash`） |
| `lib/tasks/db_guard.rake` | DB を作り直すタスクを止める |

TS 版（クリーンアーキテクチャ）との違い：

- リポジトリのインターフェースは作らず、ユースケースから Active Record のモデルを直接使います（Rails らしさを残すため）
- 入力チェック・空文字 → NULL・検索は、モデルに書きます（TS 版では domain と infrastructure に分けていた）

## テスト

```bash
bundle exec rspec        # 70 件、約 17 秒
bundle exec rubocop      # 書き方のチェック
bundle exec brakeman     # セキュリティのチェック
```

- テストは本物の DB を使います。1 件ごとにトランザクションで取り消すので、DB の中身は変わりません
- development と test は同じ DB を使います（[config/database.yml](config/database.yml)）

## 作ってみて分かったこと

- **Ruby 3.3.0 では Rails 8.1 が動かない**：Rails の中の書き方（`*`・`**` をブロックの中でも使う）を、Ruby 3.3.0 が「anonymous rest parameter is also used within block (SyntaxError)」としてエラーにしました。Ruby 3.4.5 にして動きました
- **`rails new --skip-bundle` にすると、Tailwind CSS・importmap・Turbo・Stimulus の準備もされない**：あとで `bin/rails tailwindcss:install importmap:install turbo:install stimulus:install` を実行しました
- **複合主キー**：Rails 8 は複合主キーに対応していて、`to_param` は 5 列を `_` でつないだ形（例：`131016_0001001_006_001_`）でした。TS 版で自分で作った形と同じです
- **LIKE のエスケープは Rails にある**：`sanitize_sql_like` で `%`・`_`・`\` をエスケープできます（TS 版では Prisma に無いので自分で書いた）
- **日付の型変換は、正しくない値を黙って nil にする**：「2026-02-30」は nil になり、「2026/01/01」は日付として通ります。TS 版と同じく YYYY-MM-DD だけを通すように、型変換の前の値（`read_attribute_before_type_cast`）を検査しています
- **Active Record の `save` は、行が消えていても成功扱いになる**：読んだあとにほかで削除されると、0 行の更新でも `true` が返りました。更新は `lock`（SELECT ... FOR UPDATE）で行をロックしてから行います
- **Turbo のフォーム送信**：入力エラーの画面は 422 で返さないと、画面が差し替わりません。成功したときの redirect は 303 にします
- **`bin/dev` は foreman を自動で入れようとする**：入っていないと `gem install foreman` を実行します。代わりに、Tailwind のビルドと `bin/rails server` を分けて実行しています（[docs/start-stop.md](docs/start-stop.md)）
- **項目名**：画面の項目名は CSV の列名のままです（日本語名の公式資料を確かめられていないため）
- **データの性質**（TS 版と同じ）：丁目は「一丁目」と「３丁目」の書き方が混ざっていて、「3」で「３丁目」は見つかりますが、「三丁目」は見つかりません
