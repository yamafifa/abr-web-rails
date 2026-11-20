require "rails_helper"

RSpec.describe SearchRsdt do
  subject(:search) { described_class.new }

  let(:c) { criteria(**KAMIKITAZAWA_3_1) } # 21 件

  it "1 ページ分と、件数・ページ数を返す" do
    r = search.call(criteria: c, page: 1, per_page: 10)
    expect([ r.total, r.page, r.total_pages, r.rows.size ]).to eq [ 21, 1, 3, 10 ]
  end

  it "主キー順で、ページをまたいでも重ならない" do
    all = search.call(criteria: c, page: 1, per_page: 100).rows.map(&:to_param)
    paged = (1..3).flat_map { search.call(criteria: c, page: it, per_page: 10).rows.map(&:to_param) }
    expect(paged).to eq all
    expect(all).to eq all.sort
  end

  it "最後のページは残りの件数だけ" do
    expect(search.call(criteria: c, page: 3, per_page: 10).rows.size).to eq 1
  end

  it "最後のページより後ろを指定されたら、最後のページを返す" do
    r = search.call(criteria: c, page: 999, per_page: 10)
    expect([ r.page, r.rows.size ]).to eq [ 3, 1 ]
  end

  it "0 以下のページは 1 ページ目にする" do
    expect(search.call(criteria: c, page: 0, per_page: 10).page).to eq 1
  end

  it "0 件でもページ数は 1" do
    r = search.call(criteria: criteria(town: "%"), page: 1, per_page: 10)
    expect([ r.rows, r.total, r.page, r.total_pages ]).to eq [ [], 0, 1, 1 ]
  end

  it "per_page が正しくなければエラー" do
    expect { search.call(criteria: c, page: 1, per_page: 0) }.to raise_error(ArgumentError)
  end
end
