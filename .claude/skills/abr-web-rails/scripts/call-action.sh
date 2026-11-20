#!/usr/bin/env bash
# 更新・削除を、ブラウザを使わずに送る（動作確認用）
# - Rails は CSRF トークン（偽の送信を防ぐための値）が無い送信を 422 で断るので、
#   先に編集画面を開いてトークンとセッションの Cookie を受け取ってから送る
#
# 使い方（サーバーを起動したあと）:
#   bash .claude/skills/abr-web-rails/scripts/call-action.sh update <主キーID> <戻り先> 'rsdt[city]=千代田区' 'rsdt[remarks]=テスト' ...
#   bash .claude/skills/abr-web-rails/scripts/call-action.sh delete <主キーID> <戻り先>
# 例:
#   bash .claude/skills/abr-web-rails/scripts/call-action.sh update 131016_0001001_006_002_ '/?page=2' 'rsdt[city]=千代田区' 'rsdt[remarks]=テスト'
# 結果：HTTP の状態（成功は 303、入力エラーは 422）、redirect 先、入力エラーの文
set -euo pipefail

kind=${1:?update か delete}
id=${2:?主キーID}
back=${3:-/}
shift 3 || shift $#
base=http://127.0.0.1:3000
jar=$(mktemp)
out=$(mktemp)
trap 'rm -f "$jar" "$out"' EXIT

token=$(curl -s -c "$jar" -b "$jar" "$base/" | grep -o 'name="csrf-token" content="[^"]*"' | sed 's/.*content="//;s/"$//')
[ -n "$token" ] || { echo "CSRF トークンを取れませんでした。サーバーは動いていますか？" >&2; exit 1; }

back_q=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$back")
case "$kind" in
  update) method=PATCH ;;
  delete) method=DELETE ;;
  *) echo "update か delete を指定してください" >&2; exit 1 ;;
esac

fields=(--data-urlencode "authenticity_token=$token")
for kv in "$@"; do fields+=(--data-urlencode "$kv"); done

curl -s -b "$jar" -c "$jar" -o "$out" -w 'HTTP %{http_code}  redirect=%{redirect_url}\n' \
  -X "$method" "$base/rsdt/$id?back=$back_q" "${fields[@]}"
# 入力エラーの文（422 のとき）
grep -o 'text-xs text-rose-400">[^<]*' "$out" | sed 's/.*>/  エラー: /' || true
