require "rails_helper"

RSpec.describe PagerHelper, type: :helper do
  it "ページが少なければ全部" do
    expect(helper.pager_items(1, 3)).to eq [ 1, 2, 3 ]
  end

  it "今のページの前後 2 つと、最初と最後。間は :gap" do
    expect(helper.pager_items(10, 100)).to eq [ 1, :gap, 8, 9, 10, 11, 12, :gap, 100 ]
  end

  it "最初や最後の近くでは :gap を入れない" do
    expect(helper.pager_items(2, 100)).to eq [ 1, 2, 3, 4, :gap, 100 ]
    expect(helper.pager_items(4, 7)).to eq [ 1, 2, 3, 4, 5, 6, 7 ]
  end
end
