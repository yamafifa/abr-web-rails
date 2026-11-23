# abr-web-rails

ABR（アドレス・ベース・レジストリ）の住居表示-住居マスター（`mt_rsdtdsp_rsdt`、東京都 1,752,573 件）を検索して、一覧表示・編集・削除する Web アプリの Ruby on Rails 版です。
[abr-batch](https://github.com/yamafifa/abr-batch) で確かめた「大量のデータを部分一致で探すなら、元の DB ではなく、検索用のデータを作る」の効果を、DB 検索と Elasticsearch 検索の画面で比べられるようにしています。

- Ruby 4.0.10 ＋ Rails 8.1.4.1 ＋ Active Record ＋ Tailwind CSS 4 ＋ Turbo・Stimulus ＋ RSpec
- 構成は「Rails 標準の MVC ＋ ユースケース」（`app/usecases/`）
- DB は [abr-batch](https://github.com/yamafifa/abr-batch) の MySQL を共用します（テーブルも abr-batch で作ったもの）
- ほかの版：[TypeScript（Next.js）](https://github.com/yamafifa/abr-web-ts)・[Laravel](https://github.com/yamafifa/abr-web-laravel)・[Symfony](https://github.com/yamafifa/abr-web-symfony)・[Spring Boot](https://github.com/yamafifa/abr-web-spring)

## 検索の速さ：DB 検索と Elasticsearch 検索

開発モードで画面全体を返すまでの時間（3 回測った値）：

| 条件 | DB 検索（`/`） | Elasticsearch 検索（`/es`） |
|---|---|---|
| 市区町村「町田」＋町字「木曽」 | 1.42〜1.44 秒 | 0.020〜0.022 秒 |
| 町字「西」 | 0.52 秒 | 0.023〜0.10 秒 |
| 条件なし | 0.17〜0.18 秒 | 0.016〜0.021 秒 |

- DB 検索は `city LIKE '%町田%'` のような部分一致です。前に `%` が付く LIKE は MySQL のインデックスでは速くならないので、毎回 175 万行を全部読みます
- Elasticsearch 検索は、abr-batch の `npm run es:index` で作った検索用のインデックスから探します。条件の意味と画面は DB 検索と同じです
- 詳しくは下の「[Elasticsearch 検索](#elasticsearch-検索)」を参照

## できること

- **検索**：市区町村・町字・丁目などで探して、一覧を出します。DB 検索（`/`）と Elasticsearch 検索（`/es`）の 2 つがあり、条件と画面は同じです
- **編集・削除**：abr-batch の差分更新バッチ（v4）のテストデータを作りやすくするために付けました

## 動かし方

1. abr-batch で DB を起動して、データを入れておく（abr-batch の README「動かし方」を参照）
2. Elasticsearch 検索を使うときは、abr-batch で `npm run es:index` を実行しておく（約 1 分）
3. このリポジトリで：

```bash
bundle config set --local path vendor/bundle   # gem をこのフォルダの中に入れる
bundle install
bin/rails tailwindcss:build
bin/rails server                                # http://127.0.0.1:3000
```

- 起動と停止の詳しいやり方は [docs/start-stop.md](docs/start-stop.md) にあります
- 編集・削除したデータは、abr-batch で `npm run import:v3`（約 15 秒）を実行すると元に戻せます
- **`bin/rails db:migrate` などの DB のタスクは使えません。** DB を abr-batch と共用しているので、[lib/tasks/db_guard.rake](lib/tasks/db_guard.rake) で止めています（`db:drop` で abr の DB が消える、`db:schema:load` でテーブルが空になる、などを防ぐため）

## Elasticsearch 検索

DB 検索（`/`）はそのまま残して、Elasticsearch で探す一覧（`/es`）を別に作りました。上のメニューで切り替えられ、それぞれの画面に「同じ条件で〜検索」のリンクがあります。

- **中身は `npm run es:index` を実行した時点の DB のコピー**です。画面に作成日時を出しています。この画面から編集・削除すると DB は変わりますが、Elasticsearch は次に `es:index` を実行するまで古いままです。食い違ったときは、DB 検索の画面と見比べてください
- **ページ送りは「最初へ・前へ・次へ・最後へ」**で、ページ番号はありません。Elasticsearch は、先頭から 10,000 件より先へページ番号で進めないため、主キーの続きから取る方法（search_after）にしました。URL の `after`・`before` は、そのキーの次・手前から 1 ページ分という意味です
- **文字の扱いは MySQL に合わせています**：MySQL（utf8mb4_unicode_ci）は全角と半角、ひらがなとカタカナ、濁点の有無などを同じ文字として扱います。Elasticsearch でも同じ結果になるよう、入れる側（abr-batch の `src/lib/fold.ts`）と探す側（[app/models/rsdt_fold.rb](app/models/rsdt_fold.rb)）で同じように文字をそろえています。直すときは両方を直します
- Elasticsearch には gem を使わず、Ruby 標準の Net::HTTP でつなぎます（[app/models/es_client.rb](app/models/es_client.rb)）。接続先は環境変数 `ES_URL`（既定は `http://127.0.0.1:9200`）。接続できないときは、画面にエラーの文を出します

## 構成

| 場所 | 内容 |
|---|---|
| `app/models/rsdt.rb` | Active Record のモデル。複合主キー、17 列の入力チェック、空文字 → NULL、検索のスコープ、住所の表示 |
| `app/models/rsdt_search_criteria.rb` | 検索条件（`Data.define`） |
| `app/models/rsdt_list_query.rb` | 一覧の URL ⇔ 検索条件・件数・ページ |
| `app/models/rsdt_es_list_query.rb` | Elasticsearch 検索の URL ⇔ 検索条件・件数・after・before・last |
| `app/models/rsdt_fold.rb` | Elasticsearch で探す前に、文字をそろえる（MySQL と同じ結果にするため） |
| `app/models/es_client.rb` | Elasticsearch の REST API を呼ぶ |
| `app/usecases/` | ユースケース：`SearchRsdt`（ページ番号の補正もここ）・`SearchRsdtEs`（Elasticsearch で検索）・`GetRsdt`・`UpdateRsdt`・`DeleteRsdt` |
| `app/controllers/rsdts_controller.rb` | パラメーターを読む → ユースケースを呼ぶ → 表示・redirect |
| `app/controllers/es_rsdts_controller.rb` | Elasticsearch 検索の一覧。編集・削除は `rsdts_controller.rb` の画面を使う |
| `app/controllers/concerns/back_url.rb` | 戻り先のチェック（外のサイトへ飛ばさない） |
| `app/helpers/pager_helper.rb` | ページャーに出すページ番号 |
| `app/views/rsdts/` | 一覧・一覧の表・編集・削除ボタン・検索フォーム・ページャー |
| `app/views/es_rsdts/` | Elasticsearch 検索の一覧・ページ送り |
| `app/views/shared/` | 確認モーダル・お知らせ |
| `app/javascript/controllers/` | Stimulus：確認モーダル（`confirm`）、件数を変えたら検索（`auto_submit`）、お知らせを消す（`flash`） |
| `lib/tasks/db_guard.rake` | DB を作り直すタスクを止める |

[TypeScript 版](https://github.com/yamafifa/abr-web-ts)（クリーンアーキテクチャ）との違い：

- リポジトリのインターフェースは作らず、ユースケースから Active Record のモデルを直接使います（Rails らしさを残すため）
- 入力チェック・空文字 → NULL・検索は、モデルに書きます（TypeScript 版では domain と infrastructure に分けていた）

## テスト

```bash
bundle exec rspec        # 89 件、約 20 秒
bundle exec rubocop      # 書き方のチェック
bundle exec brakeman     # セキュリティのチェック
```

- テストは本物の DB を使います。1 件ごとにトランザクションで取り消すので、DB の中身は変わりません
- Elasticsearch 検索のテストは、本物の Elasticsearch を使います。先に abr-batch で `npm run es:index` を実行しておきます
- development と test は同じ DB を使います（[config/database.yml](config/database.yml)）

## 作ってみて分かったこと

- **Ruby 3.3.0 では Rails 8.1 が動かない**：Rails の中の書き方（`*`・`**` をブロックの中でも使う）を、Ruby 3.3.0 が「anonymous rest parameter is also used within block (SyntaxError)」としてエラーにしました。Ruby 3.4.5 にして動きました（そのあと 4.0.10 に上げても動いています）
- **`rails new --skip-bundle` にすると、Tailwind CSS・importmap・Turbo・Stimulus の準備もされない**：あとで `bin/rails tailwindcss:install importmap:install turbo:install stimulus:install` を実行しました
- **複合主キー**：Rails 8 は複合主キーに対応していて、`to_param` は 5 列を `_` でつないだ形（例：`131016_0001001_006_001_`）でした。TypeScript 版で自分で作った形と同じです
- **LIKE のエスケープは Rails にある**：`sanitize_sql_like` で `%`・`_`・`\` をエスケープできます（TypeScript 版では Prisma に無いので自分で書いた）
- **日付の型変換は、正しくない値を黙って nil にする**：「2026-02-30」は nil になり、「2026/01/01」は日付として通ります。TypeScript 版と同じく YYYY-MM-DD だけを通すように、型変換の前の値（`read_attribute_before_type_cast`）を検査しています
- **Active Record の `save` は、行が消えていても成功扱いになる**：読んだあとにほかで削除されると、0 行の更新でも `true` が返りました。更新は `lock`（SELECT ... FOR UPDATE）で行をロックしてから行います
- **Turbo のフォーム送信**：入力エラーの画面は 422 で返さないと、画面が差し替わりません。成功したときの redirect は 303 にします
- **`bin/dev` は foreman を自動で入れようとする**：入っていないと `gem install foreman` を実行します。代わりに、Tailwind のビルドと `bin/rails server` を分けて実行しています（[docs/start-stop.md](docs/start-stop.md)）
- **項目名**：画面の項目名は CSV の列名のままです（日本語名の公式資料を確かめられていないため）
- **データの性質**：丁目は「一丁目」と「３丁目」の書き方が混ざっていて、「3」で「３丁目」は見つかりますが、「三丁目」は見つかりません
- **時刻は日本時間**：`config/application.rb` に `config.time_zone = "Tokyo"` を書きました（Rails の既定は UTC）。DB の日付の列は DATE 型（時刻を持たない）なので、今は時刻で結果が変わる処理はありません。DB（MySQL）の時刻は UTC のままです
