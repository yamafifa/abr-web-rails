# 一覧画面の URL が表す状態（検索条件・1 ページの件数・ページ番号）
RsdtListQuery = Data.define(:criteria, :per_page, :page) do
  per_page_options = [ 15, 30, 50, 100 ].freeze
  const_set(:PER_PAGE_OPTIONS, per_page_options)
  const_set(:DEFAULT_PER_PAGE, 15)
  # URL のクエリ名 ⇔ 検索条件の項目（URL は短くしたいので、blk・rsdt にしている）
  const_set(:PARAM_NAMES, { city: :city, town: :town, chome: :chome, blk_num: :blk, rsdt_num: :rsdt }.freeze)
  # 入力の長さの上限（テーブルの列の長さに合わせる）
  const_set(:MAX_LENGTH, { city: 80, town: 80, chome: 20, blk_num: 20, rsdt_num: 20 }.freeze)

  # URL のクエリを一覧の状態にする。おかしな値は既定値にする
  def self.from_params(params)
    first = ->(v) { (v.is_a?(Array) ? v.first : v).to_s.strip }
    criteria = RsdtSearchCriteria.new(
      **self::PARAM_NAMES.to_h { |attr, name| [ attr, first.(params[name])[0, self::MAX_LENGTH[attr]] ] }
    )
    per = Integer(first.(params[:per]), exception: false)
    page = Integer(first.(params[:page]), exception: false)
    new(
      criteria:,
      per_page: self::PER_PAGE_OPTIONS.include?(per) ? per : self::DEFAULT_PER_PAGE,
      page: page&.positive? ? page : 1
    )
  end

  # URL のクエリ（空の条件・既定値は省く）
  def to_params
    params = self.class::PARAM_NAMES.filter_map { |attr, name| [ name, criteria.public_send(attr) ] if criteria.public_send(attr).present? }.to_h
    params[:per] = per_page if per_page != self.class::DEFAULT_PER_PAGE
    params[:page] = page if page > 1
    params
  end
end
