require "rails_helper"

# 本物の Elasticsearch（abr-batch の npm run es:index で作ったインデックス）を使う
RSpec.describe SearchRsdtEs do
  subject(:search) { described_class.new }

  let(:c) { criteria(**KAMIKITAZAWA_3_1) } # 21 件

  it "DB 検索と同じ件数・同じ順で返す" do
    r = search.call(criteria: c, per_page: 100)
    db = SearchRsdt.new.call(criteria: c, page: 1, per_page: 100)
    expect(r.total).to eq 21
    expect(r.rows.map(&:to_param)).to eq db.rows.map(&:to_param)
  end

  it "画面に出す値は DB と同じ（住所・日付）" do
    row = search.call(criteria: c, per_page: 1).rows.first
    db = Rsdt.find_by_param(row.to_param)
    expect([ row.address, row.efct_date, row.ablt_date ]).to eq [ db.address, db.efct_date, db.ablt_date ]
  end

  it "次へ・前へで、重ならずに行き来できる" do
    p1 = search.call(criteria: c, per_page: 10)
    p2 = search.call(criteria: c, per_page: 10, after: p1.next_key)
    p3 = search.call(criteria: c, per_page: 10, after: p2.next_key)
    expect([ p1.from, p2.from, p3.from ]).to eq [ 1, 11, 21 ]
    expect([ p1.prev_key, p3.next_key ]).to eq [ nil, nil ]
    expect((p1.rows + p2.rows + p3.rows).map(&:to_param)).to eq search.call(criteria: c, per_page: 100).rows.map(&:to_param)
    back = search.call(criteria: c, per_page: 10, before: p3.prev_key)
    expect(back.rows.map(&:to_param)).to eq p2.rows.map(&:to_param)
  end

  it "前へで 1 ページに満たないときは、先頭の 1 ページを出す" do
    p2 = search.call(criteria: c, per_page: 10, after: search.call(criteria: c, per_page: 5).next_key)
    back = search.call(criteria: c, per_page: 10, before: p2.prev_key)
    expect([ back.from, back.rows.size, back.prev_key ]).to eq [ 1, 10, nil ]
  end

  it "最後へは、最後の 1 ページ分を出す" do
    r = search.call(criteria: c, per_page: 10, last: true)
    expect([ r.from, r.rows.size, r.next_key ]).to eq [ 12, 10, nil ]
  end

  it "MySQL と同じく、全角と半角を同じ文字として探す（「3」で「３丁目」）" do
    expect(search.call(criteria: criteria(town: "上北沢", chome: "3"), per_page: 1).total)
      .to eq SearchRsdt.new.call(criteria: criteria(town: "上北沢", chome: "3"), page: 1, per_page: 1).total
  end

  it "* ? \\ は、ただの文字として探す" do
    expect(search.call(criteria: criteria(city: "*"), per_page: 1).total).to eq 0
    expect(search.call(criteria: criteria(town: "?"), per_page: 1).total).to eq 0
  end

  it "インデックスの名前と作成日時を返す" do
    r = search.call(criteria: criteria(city: "存在しない市"), per_page: 1)
    expect(r.index).to match(/\Arsdt_\d{8}-\d{6}\z/)
    expect(r.built_at).to match(/\A\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\z/)
  end

  it "Elasticsearch に接続できないときは、エラーの文を返す" do
    r = described_class.new(client: EsClient.new(url: "http://127.0.0.1:1")).call(criteria: c, per_page: 10)
    expect([ r.rows, r.total ]).to eq [ [], 0 ]
    expect(r.error).to include("接続できません")
  end
end
