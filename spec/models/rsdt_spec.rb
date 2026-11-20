require "rails_helper"

RSpec.describe Rsdt do
  let(:rsdt) { Rsdt.find_by_param(EXISTING_ID) }

  describe "主キー" do
    it "5 列を _ でつなぐ。rsdt2_id が空なら末尾が _ になる" do
      expect(rsdt.to_param).to eq "131016_0001001_006_001_"
    end

    it "key_from_param で元に戻せる" do
      expect(Rsdt.key_from_param(rsdt.to_param)).to eq(lg_code: "131016", machiaza_id: "0001001", blk_id: "006", rsdt_id: "001", rsdt2_id: "")
    end

    { "区切りが足りない" => "131016_0001001_006_001", "区切りが多い" => "131016_0001001_006_001__",
      "必須の列が空" => "131016__006_001_", "空文字" => "" }.each do |label, param|
      it "形がおかしければ nil（#{label}）" do
        expect(Rsdt.key_from_param(param)).to be_nil
      end
    end

    it "find_by_param：無ければ nil" do
      expect(Rsdt.find_by_param(MISSING_ID)).to be_nil
    end
  end

  describe "入力の決まり" do
    def errors_for(**attrs)
      r = Rsdt.new(city: "千代田区", **attrs)
      r.valid?
      r.errors.to_hash
    end

    it "17 列すべてに決まりがある" do
      expect(Rsdt::EDITABLE_ATTRIBUTES.size).to eq 17
    end

    it "前後の空白を取り、空文字・空白だけは nil にする" do
      r = Rsdt.new(city: "  千代田区 ", ward: "", koaza: "   ")
      expect([ r.city, r.ward, r.koaza ]).to eq [ "千代田区", nil, nil ]
    end

    it "city は必須" do
      expect(errors_for(city: " ")).to eq(city: [ "必須です" ])
    end

    it "最大文字数は、日本語も 1 文字として数える" do
      expect(errors_for(city: "あ" * 20)).to be_empty
      expect(errors_for(city: "あ" * 21)).to eq(city: [ "20 文字以内で入力してください" ])
    end

    it "サロゲートペアの文字（𠮷）も 1 文字として数える" do
      expect(errors_for(city: "𠮷" * 20)).to be_empty
    end

    %w[2026-02-30 2026/01/01 2026-1-1 abc].each do |d|
      it "正しくない日付はエラー（#{d}）" do
        expect(errors_for(ablt_date: d)).to eq(ablt_date: [ "日付の形式が正しくありません（YYYY-MM-DD）" ])
      end
    end

    it "うるう日と、空の日付は通る" do
      expect(errors_for(efct_date: "2024-02-29", ablt_date: "")).to be_empty
    end

    it "エラーは、すべての列についてまとめて返す" do
      expect(errors_for(city: "", status_flg: "12", efct_date: "x").keys).to contain_exactly(:city, :status_flg, :efct_date)
    end
  end

  describe "#address" do
    it "市区町村・町字丁目・番号をつなぐ" do
      expect(rsdt.address).to eq "千代田区 内幸町一丁目 6-1"
    end

    it "無い項目は飛ばし、ward・koaza・rsdt_num2 があれば入れる" do
      expect(Rsdt.new(city: "千代田区", oaza_cho: "内幸町").address).to eq "千代田区 内幸町"
      expect(Rsdt.new(city: "千代田区", ward: "区", oaza_cho: "内幸町", koaza: "小字", blk_num: "6", rsdt_num: "1", rsdt_num2: "3").address)
        .to eq "千代田区 区 内幸町 小字 6-1-3"
    end
  end

  describe ".search（本物の DB）" do
    it "条件なしなら全件" do
      expect(Rsdt.search(RsdtSearchCriteria.empty).count).to eq 1_752_573
    end

    it "「%」「_」は、ただの文字として探す（全件が出ない）" do
      expect(Rsdt.search(criteria(town: "%")).count).to eq 0
      expect(Rsdt.search(criteria(town: "_")).count).to eq 0
    end

    it "全角と半角は同じ文字として探せる（DB の照合順序による）" do
      zenkaku = Rsdt.search(criteria(town: "上北沢", chome: "３")).count
      expect(zenkaku).to be_positive
      expect(Rsdt.search(criteria(town: "上北沢", chome: "3")).count).to eq zenkaku
    end

    it "blk_num は完全一致（「1」で 10 や 21 は出ない）" do
      rows = Rsdt.search(criteria(**KAMIKITAZAWA_3_1)).to_a
      expect(rows.size).to eq 21
      expect(rows.map(&:blk_num).uniq).to eq [ "1" ]
    end

    it "主キー順に並べられる" do
      expect(Rsdt.in_key_order.limit(2).map(&:to_param)).to eq %w[131016_0001001_006_001_ 131016_0001001_006_002_]
    end
  end
end
