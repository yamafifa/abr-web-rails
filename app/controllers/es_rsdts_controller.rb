# Elasticsearch で検索する一覧
# 編集・削除は DB 検索と同じ画面（RsdtsController）を使い、戻り先をこの画面にする
class EsRsdtsController < ApplicationController
  def index
    @query = RsdtEsListQuery.from_params(params)
    q = @query
    @result = SearchRsdtEs.new.call(criteria: q.criteria, per_page: q.per_page, after: q.after, before: q.before, last: q.last)
    # 編集・削除のあとに戻ってくる URL（今の URL。同じ after・before なら同じページが出る）
    @back = es_rsdts_path(q.to_params)
  end
end
