# 住居表示-住居マスター（mt_rsdtdsp_rsdt）の 1 行
# テーブルは abr-batch で作ったものを共用する。主キーは 5 列の複合キー
class Rsdt < ApplicationRecord
  self.table_name = "mt_rsdtdsp_rsdt"
  self.primary_key = %i[lg_code machiaza_id blk_id rsdt_id rsdt2_id]

  # 主キー以外の 17 列の決まり（最大文字数はテーブル定義に合わせる）。画面の項目名は列名のまま
  ATTRIBUTE_RULES = [
    { name: :city, max: 20, required: true },
    { name: :ward, max: 20 },
    { name: :oaza_cho, max: 80 },
    { name: :chome, max: 20 },
    { name: :koaza, max: 80 },
    { name: :machiaza_dist, max: 10 },
    { name: :blk_num, max: 20 },
    { name: :rsdt_num, max: 20 },
    { name: :rsdt_num2, max: 20 },
    { name: :basic_rsdt_div, max: 1 },
    { name: :rsdt_addr_flg, max: 1 },
    { name: :rsdt_addr_mtd_code, max: 1 },
    { name: :status_flg, max: 1 },
    { name: :efct_date, type: :date },
    { name: :ablt_date, type: :date },
    { name: :src_code, max: 2 },
    { name: :remarks, max: 255 }
  ].freeze
  EDITABLE_ATTRIBUTES = ATTRIBUTE_RULES.map { it[:name] }.freeze
  TEXT_RULES = ATTRIBUTE_RULES.reject { it[:type] == :date }.freeze
  DATE_ATTRIBUTES = ATTRIBUTE_RULES.select { it[:type] == :date }.map { it[:name] }.freeze

  # 前後の空白を取り、空文字は NULL にする（abr-batch の取り込みと同じ扱い）
  normalizes(*TEXT_RULES.map { it[:name] }, with: ->(v) { v.to_s.strip.presence })

  validates :city, presence: { message: "必須です" }
  # 文字数は String#length（コードポイント単位）で数える。MySQL の VARCHAR と同じ
  TEXT_RULES.each do |rule|
    validates rule[:name], length: { maximum: rule[:max], message: "%{count} 文字以内で入力してください" }, allow_nil: true
  end
  validate :dates_must_be_yyyy_mm_dd

  # 主キーを 1 つの文字列にしたもの（例：131016_0001001_006_001_）。Rails の複合キーの to_param と同じ形
  # rsdt2_id は空文字が多いので、末尾が "_" で終わることがある
  def self.key_from_param(param)
    parts = param.to_s.split(param_delimiter, -1)
    return nil unless parts.size == 5 && parts.first(4).all?(&:present?)

    primary_key.map(&:to_sym).zip(parts).to_h
  end

  def self.find_by_param(param)
    key = key_from_param(param)
    key && find_by(key)
  end

  scope :in_key_order, -> { order(*primary_key) }

  # 検索条件（RsdtSearchCriteria）で絞り込む。空の条件は使わない
  # 部分一致はインデックスが効かないので、全件を読む（全件 175 万件で約 1 秒）
  scope :search, lambda { |c|
    rel = all
    like = ->(s) { "%#{sanitize_sql_like(s)}%" } # % _ \ を、ただの文字として探す
    rel = rel.where("city LIKE :w OR ward LIKE :w", w: like.(c.city)) if c.city.present?
    rel = rel.where("oaza_cho LIKE :w OR koaza LIKE :w", w: like.(c.town)) if c.town.present?
    rel = rel.where("chome LIKE ?", like.(c.chome)) if c.chome.present?
    # blk_num・rsdt_num は完全一致（値はすべて数字なので、部分一致だと「1」で 10・21 なども出てしまうため）
    rel = rel.where(blk_num: c.blk_num) if c.blk_num.present?
    rel = rel.where(rsdt_num: c.rsdt_num) if c.rsdt_num.present?
    rel
  }

  # 画面に出す住所（例：千代田区 内幸町一丁目 6-1）
  def address
    town = [ city, ward, "#{oaza_cho}#{chome}", koaza ].compact_blank.join(" ")
    num = [ blk_num, rsdt_num, rsdt_num2 ].compact_blank.join("-")
    num.present? ? "#{town} #{num}" : town
  end

  private

  # 日付は YYYY-MM-DD だけを受け付ける（Rails の型変換は 2026/01/01 なども日付にし、2026-02-30 は黙って nil にするため）
  def dates_must_be_yyyy_mm_dd
    DATE_ATTRIBUTES.each do |attr|
      raw = read_attribute_before_type_cast(attr)
      next unless raw.is_a?(String) && raw.strip.present?

      y, m, d = raw.strip.match(/\A(\d{4})-(\d{2})-(\d{2})\z/)&.captures&.map(&:to_i)
      errors.add(attr, "日付の形式が正しくありません（YYYY-MM-DD）") unless y && Date.valid_date?(y, m, d)
    end
  end
end
