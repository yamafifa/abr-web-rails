require "rails_helper"

RSpec.describe RsdtListQuery do
  def parse(**params) = RsdtListQuery.from_params(ActionController::Parameters.new(params))

  describe ".from_params" do
    it "何も無ければ、条件なし・15 件・1 ページ目" do
      expect(parse).to eq RsdtListQuery.new(criteria: RsdtSearchCriteria.empty, per_page: 15, page: 1)
    end

    it "URL の名前（blk・rsdt）を検索条件の項目に読み替える。前後の空白は取る" do
      q = parse(city: " 世田谷 ", town: "上北沢", chome: "3", blk: "1", rsdt: "2", per: "30", page: "4")
      expect(q.criteria).to eq RsdtSearchCriteria.new(city: "世田谷", town: "上北沢", chome: "3", blk_num: "1", rsdt_num: "2")
      expect([ q.per_page, q.page ]).to eq [ 30, 4 ]
    end

    %w[0 20 abc].each do |per|
      it "選べない件数（#{per}）は 15 件にする" do
        expect(parse(per:).per_page).to eq 15
      end
    end

    %w[0 -1 1.5 abc].each do |page|
      it "おかしなページ番号（#{page}）は 1 にする" do
        expect(parse(page:).page).to eq 1
      end
    end

    it "同じ名前が複数あれば、最初のものを使う" do
      expect(parse(city: %w[新宿 渋谷]).criteria.city).to eq "新宿"
    end

    it "長すぎる入力は切り詰める" do
      expect(parse(blk: "1" * 50).criteria.blk_num.size).to eq 20
    end
  end

  describe "#to_params" do
    it "条件なし・既定値なら空" do
      expect(parse.to_params).to eq({})
    end

    it "空の条件と既定値は省く" do
      expect(parse(city: "世田谷", blk: "1", per: "15", page: "1").to_params).to eq(city: "世田谷", blk: "1")
    end

    it "from_params で元に戻せる" do
      q = parse(city: "世田谷", town: "上北沢", chome: "3", blk: "1", rsdt: "2", per: "50", page: "7")
      expect(RsdtListQuery.from_params(ActionController::Parameters.new(q.to_params.transform_values(&:to_s)))).to eq q
    end
  end
end
