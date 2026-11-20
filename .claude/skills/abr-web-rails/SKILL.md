---
name: abr-web-rails
description: abr-web-rails（住居表示-住居マスターを検索・一覧・編集・削除する Ruby on Rails のアプリ）で、機能の追加・修正・テスト・動作確認・ドキュメント更新をするときの手順と、これまでに分かった落とし穴。検索条件や画面の追加、モデル・ユースケース・コントローラーのどこに書くかの判断、gem の追加、DB に関わる rails コマンドを使うときに使う。
---

# abr-web-rails の作業手順と知見

## 前提

- Ruby 3.4.5（このフォルダだけ。`.ruby-version`）＋ Rails 8.1.4.1 ＋ Active Record（mysql2）＋ Tailwind CSS 4（tailwindcss-rails）＋ importmap・Turbo・Stimulus ＋ RSpec（rspec-rails 8.1.0）
- gem はプロジェクトの中（`vendor/bundle`）に入れている。コマンドは `bundle exec` か `bin/rails` で実行する
- DB は **abr-batch の MySQL を共用**（ポート 3307、テーブル `mt_rsdtdsp_rsdt`、1,752,573 件）。development と test は同じ DB
- 勉強用に、同じものを TS（abr-web-ts）・Laravel でも作る。機能・画面・デザイン・ユースケースの名前（`SearchRsdt`・`GetRsdt`・`UpdateRsdt`・`DeleteRsdt`）をそろえる
- サーバーは 3000 番ポート（ほかの版と同じ）。`127.0.0.1` で待ち受ける

## してはいけないこと（DB を共用しているため）

- **DB を作り直す rails コマンドを実行しない。** `db:drop`・`db:create`・`db:migrate`・`db:schema:load`・`db:prepare`・`db:test:prepare`・`db:reset`・`db:seed` など
  - [lib/tasks/db_guard.rake](../../../lib/tasks/db_guard.rake) で止めてあるが、止まるかを確かめるために実行してはいけない（止める仕組みが壊れていれば DB が消える）。確かめるときは、タスクを実行せずに中身を調べる：

```bash
bin/rails runner 'Rails.application.load_tasks; %w[db:drop db:migrate db:schema:load db:test:prepare db:prepare].each { |t| puts "#{t}: #{Rake::Task[t].actions.map { it.source_location.first }.uniq} prereqs=#{Rake::Task[t].prerequisites}" }'
# どれも lib/tasks/db_guard.rake だけで、prereqs が [] なら止まる
```

- マイグレーションファイルを作らない（`rails generate model` は `--skip-migration` を付けるか、モデルを手で書く）
- `spec/rails_helper.rb` に `ActiveRecord::Migration.maintain_test_schema!` を戻さない。`config/environments/test.rb` の `maintain_test_schema = false` も消さない（テストのたびにテーブルが作り直されて空になるおそれがある）
- `bin/setup` に `db:prepare` を戻さない
- `bin/dev` は使わない（初回に `gem install foreman` を実行する）。使うなら先にユーザーの了解を取る

## 書く場所の決まり（MVC ＋ ユースケース）

| 場所 | 書くもの |
|---|---|
| `app/models/rsdt.rb` | 複合主キー、17 列の決まり（`ATTRIBUTE_RULES`）、入力チェック、空文字 → NULL（`normalizes`）、検索（`scope :search`）、住所の表示（`#address`） |
| `app/models/rsdt_search_criteria.rb`・`rsdt_list_query.rb` | 検索条件と、一覧の URL ⇔ 状態の変換（`Data.define`） |
| `app/usecases/` | ユースケース（`#call` を持つクラス）。Active Record のモデルを直接使う（リポジトリのインターフェースは作らない） |
| `app/controllers/` | パラメーターを読む → ユースケースを呼ぶ → 表示・redirect だけ |
| `app/views/`・`app/javascript/controllers/` | 画面と Stimulus |

- TS 版（クリーンアーキテクチャ）とは違い、Rails らしさを残すため、入力チェックや検索はモデルに書く
- 新しいクラスは Zeitwerk（ファイル名からクラスを読み込む仕組み）に合わせる：`app/usecases/search_rsdt.rb` → `SearchRsdt`
- Ruby 3.4 なので、ブロックの引数に `it` を使っている

### 検索条件を足すとき

1. `app/models/rsdt_search_criteria.rb` の項目
2. `app/models/rsdt.rb` の `scope :search`（部分一致は `sanitize_sql_like` でエスケープ）
3. `app/models/rsdt_list_query.rb` の `PARAM_NAMES`（URL の名前）と `MAX_LENGTH`
4. `app/views/rsdts/_search_form.html.erb` の入力欄
5. テスト（`spec/models/rsdt_spec.rb`・`rsdt_list_query_spec.rb`・`spec/requests/rsdts_spec.rb`）と README

部分一致か完全一致かは、値を見てから決める（`blk_num`・`rsdt_num` は全件が半角数字なので完全一致）。

## テストと確認

```bash
bundle exec rspec        # 70 件、約 17 秒。本物の DB を使い、1 件ごとにトランザクションで取り消す
bundle exec rubocop      # 指摘 0 件を保つ。直すときは bundle exec rubocop -a
bundle exec brakeman -q  # セキュリティ警告 0 件を保つ
```

- テストで使う行は [spec/support/rsdt_helpers.rb](../../../spec/support/rsdt_helpers.rb) の定数（`EXISTING_ID`・`MISSING_ID`・`KAMIKITAZAWA_3_1`）。元のデータにある行を使う
- テストは「全件 1,752,573 件」を前提にしている。件数が違うと落ちるので、先に DB を元に戻す
- 確認のあとは、DB が元のままか必ず確かめる。変わっていたら abr-batch で `npm run import:v3`（約 15 秒）で戻す

```bash
docker compose -f ../abr-batch/compose.yaml exec -T db mysql -uabr -pabr abr -e 'select count(*) from mt_rsdtdsp_rsdt; checksum table mt_rsdtdsp_rsdt'
# 元のデータ：1752573 件、チェックサム 967527444
```

### 画面の確認（ブラウザが無い環境）

- 一覧・編集画面は `curl` で HTML を取って、件数や値を `grep` する
- 更新・削除は [scripts/call-action.sh](scripts/call-action.sh) で送る（CSRF トークンを先に取ってから送る）

```bash
bash .claude/skills/abr-web-rails/scripts/call-action.sh update 131016_0001001_006_002_ '/?page=2' 'rsdt[city]=' 'rsdt[status_flg]=12'
# → HTTP 422 と入力エラーの文。成功すると HTTP 303 と redirect 先
```

- 見た目・モーダルの動きは確かめられないので、「確かめていない」とユーザーに伝える

### サーバーの起動と停止

```bash
bin/rails tailwindcss:build       # 画面に新しい Tailwind のクラスを書いたら、実行し直す
bin/rails server -b 127.0.0.1 -p 3000
kill $(cat tmp/pids/server.pid)   # 止める
```

- development モードなので、Ruby・ERB・JS の変更はサーバーを起動し直さなくても反映される
- 3000 番がほかの版（TS 版など）に使われていないか、先に `ss -ltn | grep :3000` で確かめる

## 分かっている落とし穴

| 症状 | 原因と対処 |
|---|---|
| `anonymous rest parameter is also used within block (SyntaxError)`（actionview の中） | Ruby 3.3.0 のバグで Rails 8.1 が読み込めない。このフォルダは Ruby 3.4.5 にした |
| `rails new` のあと、Tailwind・importmap・Turbo・Stimulus が無い | `--skip-bundle` を付けると、それらの準備もされない。`bin/rails tailwindcss:install importmap:install turbo:install stimulus:install` を実行した |
| 日付に「2026-02-30」を入れるとエラーにならず NULL になる／「2026/01/01」が通る | Active Record の日付の型変換は、正しくない値を黙って nil にし、いろいろな書き方を受け付ける。`read_attribute_before_type_cast` で、型変換の前の値を YYYY-MM-DD か検査している |
| 削除された行の更新が「成功」になる | Active Record の `save` は、0 行の更新でも `true` を返す（試して確かめた）。`UpdateRsdt` は `Rsdt.lock.find_by` で行をロックしてから更新する |
| 入力エラーのとき、画面が変わらない | Turbo はフォーム送信の応答が 4xx・5xx でないと HTML を差し替えない。`render :edit, status: :unprocessable_content`。成功の redirect は `status: :see_other`（303） |
| 削除ボタンを編集フォームの中に置けない | `button_to` は自分のフォームを作るので、フォームの中に入れるとフォームが入れ子になる。編集フォームの外に置いた |
| 確認モーダルが出ずに送信される | `confirm_controller.js` は、囲んだ要素の `submit` を止めて `<dialog>` を開き、「確定」で `requestSubmit()` し直す。`data-action="submit->confirm#open"` を、フォームを囲む要素に付ける |
| describe の中で `RsdtHelpers::...` の定数が見つからない | モジュールを `include` しても、定数は describe ブロックからは見えない。テスト用の定数は `spec/support/rsdt_helpers.rb` のトップレベルに置いた |
| helper のテストで `helper` が無い | `RSpec.describe PagerHelper, type: :helper` のように type を付ける |
| curl で更新・削除を送ると 422 | CSRF トークンが無いため。先に画面を開いて `csrf-token` と Cookie を取ってから送る（`call-action.sh`） |

## データの性質

- 複合主キーの `to_param` は 5 列を `_` でつないだ形（例：`131016_0001001_006_001_`）。`rsdt2_id` が空なので末尾が `_`。`Rsdt.key_from_param` で元に戻す
- `chome` は「一丁目」と「３丁目」が混ざっている。照合順序で全角と半角は同じになるが、漢数字は別
- `ward` は全件 NULL
- 部分一致はインデックスが効かず、件数を数えるのに全件を読む（約 1 秒）

## 書いてはいけないこと

- **列の日本語名を書かない。** 公式の仕様書で確かめられていないので、画面の項目名は CSV の列名のまま。ユーザーが言った呼び方（「市区町村」「町字」「丁目」）は使ってよい
- 実際に測っていない数字や、試していない動きを、確かめたこととして書かない

## gem の追加

- 何を入れるか伝えて、了解を取ってから入れる。`bundle add <gem> --version "<版>"` で版を固定する
- できれば出てから 2 週間以上たった版にする

## ドキュメントとコミット

- README は入口（できること・動かし方・構成・テスト・作ってみて分かったこと）。起動と停止は `docs/start-stop.md`
- 仕様を変えたら、README の「できること」「作ってみて分かったこと」も直す。TS 版とそろえる機能なら、TS 版との違いも書く
- コミットと push は、ユーザーの了解を取ってから。メッセージは日本語で、最後に `Co-Authored-By` の行を付ける
- GitHub は非公開リポジトリにする（TS 版と同じ）。abr-batch 側からは触れない
- `vendor/bundle`・`log/`・`tmp/`・`config/master.key`・`.env*` は Git に入れない（`.gitignore` 済み）。コミットの前に、個人情報（本名・メールアドレスなど）が入っていないか確かめる
