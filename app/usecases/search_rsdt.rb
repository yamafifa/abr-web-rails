# 住居を検索して、1 ページ分を返す
class SearchRsdt
  # page は実際に表示したページ（最後のページより後ろを指定されたら、最後のページ）。total_pages は 0 件でも 1
  Result = Data.define(:rows, :total, :page, :total_pages)

  def call(criteria:, page:, per_page:)
    raise ArgumentError, "per_page が正しくありません: #{per_page}" unless per_page.is_a?(Integer) && per_page.positive?

    scope = Rsdt.search(criteria)
    total = scope.count
    total_pages = [ (total + per_page - 1) / per_page, 1 ].max
    current = page.to_i.clamp(1, total_pages)
    rows = scope.in_key_order.offset((current - 1) * per_page).limit(per_page).to_a
    Result.new(rows:, total:, page: current, total_pages:)
  end
end
