# Elasticsearch（abr-batch の es:index で作った別名 rsdt）で住居を検索して、1 ページ分を返す
# - 条件の意味は DB 検索（Rsdt.search）と同じ。部分一致は wildcard、完全一致は term で探す
# - 文字は RsdtFold でそろえてから探す（MySQL の utf8mb4_unicode_ci と同じように見つけるため）
# - 並びは主キー順。ページは search_after で送る（Elasticsearch は先頭から 10,000 件より先へ from で進めないため）
class SearchRsdtEs
  ALIAS = "rsdt".freeze
  # 検索条件の項目 → 部分一致で探す列（どれかに当たればよい）
  WILDCARD_FIELDS = { city: %w[city ward], town: %w[oaza_cho koaza], chome: %w[chome] }.freeze
  # 検索条件の項目 → 完全一致で探す列
  EXACT_FIELDS = { blk_num: "blk_num", rsdt_num: "rsdt_num" }.freeze

  # from：このページの先頭が何件目か（0 件なら 0）
  # prev_key・next_key：「前へ」「次へ」のリンクに使うキー。nil ならそちらにページは無い
  # index：検索したインデックスの名前（rsdt_日時）。error：失敗したときの文
  Result = Data.define(:rows, :total, :from, :prev_key, :next_key, :index, :error) do
    # インデックスを作った日時（名前の rsdt_20261121-215617 から読む）
    def built_at
      m = index.to_s.match(/_(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)\z/)
      m && "#{m[1]}-#{m[2]}-#{m[3]} #{m[4]}:#{m[5]}:#{m[6]}"
    end
  end

  def initialize(client: EsClient.new)
    @client = client
  end

  def call(criteria:, per_page:, after: nil, before: nil, last: false)
    raise ArgumentError, "per_page が正しくありません: #{per_page}" unless per_page.is_a?(Integer) && per_page.positive?

    filters = filters(criteria)
    hits, total, index = fetch(filters, per_page, after:, before:, last:)
    # 「前へ」で 1 ページに満たなかったら、先頭まで来ているので、先頭の 1 ページを出す
    hits, total, index = fetch(filters, per_page) if before && hits.size < per_page

    first_key = hits.first&.dig("_source", "key")
    # このページより前に何件あるか（何件目からかを出すため）
    before_count = first_key ? count(filters + [ { range: { key: { lt: first_key } } } ]) : 0
    Result.new(
      rows: hits.map { to_rsdt(it["_source"]) },
      total:,
      from: hits.empty? ? 0 : before_count + 1,
      prev_key: before_count.positive? ? first_key : nil,
      next_key: before_count + hits.size < total ? hits.last.dig("_source", "key") : nil,
      index: index || alias_target,
      error: nil
    )
  rescue EsClient::NotFound
    failure("Elasticsearch にインデックス #{ALIAS} がありません。abr-batch で npm run es:index を実行してください")
  rescue EsClient::Error => e
    failure(e.message)
  end

  private

  def filters(c)
    wildcards = WILDCARD_FIELDS.filter_map do |attr, cols|
      value = c.public_send(attr)
      next if value.blank?

      pattern = "*#{escape_wildcard(RsdtFold.call(value))}*"
      { bool: { should: cols.map { { wildcard: { "fold.#{it}": { value: pattern } } } }, minimum_should_match: 1 } }
    end
    exacts = EXACT_FIELDS.filter_map do |attr, col|
      value = c.public_send(attr)
      { term: { "fold.#{col}": RsdtFold.call(value) } } if value.present?
    end
    wildcards + exacts
  end

  # wildcard の特別な文字（* ? \）を、ただの文字として探す
  def escape_wildcard(str) = str.gsub(/[\\*?]/) { "\\#{it}" }

  # 1 ページ分を取る。逆順で取ったときは、主キー順に並べ直して返す
  def fetch(filters, per_page, after: nil, before: nil, last: false)
    desc = before.present? || last
    body = {
      track_total_hits: true,
      size: per_page,
      sort: [ { key: desc ? "desc" : "asc" } ],
      query: { bool: { filter: filters } }
    }
    body[:search_after] = [ after || before ] if after || before
    res = @client.post("/#{ALIAS}/_search", body)
    hits = res.dig("hits", "hits")
    [ desc ? hits.reverse : hits, res.dig("hits", "total", "value"), hits.first&.dig("_index") ]
  end

  def count(filters) = @client.post("/#{ALIAS}/_count", { query: { bool: { filter: filters } } })["count"]

  def alias_target = @client.get("/_alias/#{ALIAS}").keys.first

  # 画面の部品（住所の表示・編集のリンクなど）を DB 検索と同じにするため、Rsdt にする（DB には読みに行かない）
  def to_rsdt(source) = Rsdt.instantiate(source.slice(*Rsdt.column_names))

  def failure(message) = Result.new(rows: [], total: 0, from: 0, prev_key: nil, next_key: nil, index: nil, error: message)
end
