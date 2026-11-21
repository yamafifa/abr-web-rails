require "rails_helper"

RSpec.describe RsdtFold do
  it "全角と半角、大文字と小文字をそろえる" do
    expect(described_class.call("３丁目ＡＢｃ")).to eq "3丁目abc"
  end

  it "カタカナをひらがなにして、濁点・半濁点を消す" do
    expect(described_class.call("パガあ")).to eq "はかあ"
  end

  it "小さい仮名を大きくする（ヶ → け、ヵ → か）" do
    expect(described_class.call("ヶヵっ")).to eq "けかつ"
  end

  it "CJK 互換漢字はそのまま残す（MySQL は別の文字として扱う）" do
    compat = [ 0xFA10 ].pack("U") # 塚（互換漢字）
    expect(described_class.call(compat)).to eq compat
    expect(described_class.call("塚")).to eq "塚"
  end
end
