require "rails_helper"

RSpec.describe RsdtEsListQuery do
  it "検索条件・件数・after を URL から読み、URL に戻せる" do
    q = described_class.from_params(ActionController::Parameters.new(town: "上北沢", per: "30", after: EXISTING_ID))
    expect([ q.criteria.town, q.per_page, q.after, q.before, q.last ]).to eq [ "上北沢", 30, EXISTING_ID, nil, false ]
    expect(q.to_params).to eq(town: "上北沢", per: 30, after: EXISTING_ID)
  end

  it "キーの形でない after・before は無視する" do
    q = described_class.from_params(ActionController::Parameters.new(after: "1 OR 1=1", before: [ "x" ]))
    expect([ q.after, q.before ]).to eq [ nil, nil ]
  end

  it "first_page はページの位置だけを外す" do
    q = described_class.from_params(ActionController::Parameters.new(chome: "3", before: EXISTING_ID, last: "1"))
    expect(q.first_page.to_params).to eq(chome: "3")
  end
end
