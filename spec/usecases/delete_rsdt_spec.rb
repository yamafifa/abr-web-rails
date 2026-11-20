require "rails_helper"

RSpec.describe DeleteRsdt do
  it "削除する" do
    described_class.new.call(EXISTING_ID)
    expect(GetRsdt.new.call(EXISTING_ID)).to be_nil
  end

  it "すでに無くても、ID の形がおかしくてもエラーにしない" do
    expect { described_class.new.call(MISSING_ID) }.not_to raise_error
    expect { described_class.new.call("bad") }.not_to raise_error
  end
end

RSpec.describe GetRsdt do
  it "あれば返し、無ければ nil" do
    expect(described_class.new.call(EXISTING_ID).city).to eq "千代田区"
    expect(described_class.new.call(MISSING_ID)).to be_nil
  end
end
