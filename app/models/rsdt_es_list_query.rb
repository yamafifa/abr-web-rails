# Elasticsearch 検索の画面の URL が表す状態（検索条件・1 ページの件数・どこから表示するか）
# ページ番号の代わりに、主キーの文字列（キー）でページを送る（search_after）
# - after：このキーの次から 1 ページ分（「次へ」）
# - before：このキーの手前の 1 ページ分（「前へ」）
# - last：最後の 1 ページ分（「最後へ」）
# - どれも無ければ、先頭から 1 ページ分
RsdtEsListQuery = Data.define(:criteria, :per_page, :after, :before, :last) do
  # キーの形（例：131016_0001001_006_001_）。おかしな値は無視する
  const_set(:KEY_FORMAT, /\A\d{6}_\d{7}_\d{3}_\d{3}_(\d{5})?\z/)

  def self.from_params(params)
    base = RsdtListQuery.from_params(params) # 検索条件と件数の読み方は DB 検索と同じ
    key = ->(name) { v = params[name]; v if v.is_a?(String) && v.match?(self::KEY_FORMAT) }
    new(criteria: base.criteria, per_page: base.per_page, after: key.(:after), before: key.(:before), last: params[:last] == "1")
  end

  # URL のクエリ（空の条件・既定値は省く）
  def to_params
    params = RsdtListQuery.new(criteria:, per_page:, page: 1).to_params
    params[:after] = after if after
    params[:before] = before if before
    params[:last] = 1 if last
    params
  end

  # ページの位置を外したもの（検索条件と件数だけ）
  def first_page = with(after: nil, before: nil, last: false)
end
