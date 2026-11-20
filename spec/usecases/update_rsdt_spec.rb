require "rails_helper"

# テストは 1 件ごとにトランザクションで取り消すので、DB の中身は変わらない
RSpec.describe UpdateRsdt do
  subject(:update) { described_class.new }

  let(:rsdt) { Rsdt.find_by_param(EXISTING_ID) }

  it "正しい入力なら更新する。主キーは変わらない" do
    r = update.call(EXISTING_ID, input_of(rsdt, remarks: " テスト 100%_ ", ablt_date: "2026-11-20", oaza_cho: ""))
    expect(r.status).to eq :updated
    saved = Rsdt.find_by_param(EXISTING_ID)
    expect([ saved.remarks, saved.ablt_date, saved.oaza_cho ]).to eq [ "テスト 100%_", Date.new(2026, 11, 20), nil ]
  end

  it "入力されなかった列は NULL になる" do
    update.call(EXISTING_ID, { city: "千代田区" })
    expect(Rsdt.find_by_param(EXISTING_ID).oaza_cho).to be_nil
  end

  it "入力が正しくなければ、更新しないでエラーを返す" do
    r = update.call(EXISTING_ID, input_of(rsdt, city: "", remarks: "テスト"))
    expect(r.status).to eq :invalid
    expect(r.rsdt.errors.to_hash).to eq(city: [ "必須です" ])
    expect(Rsdt.find_by_param(EXISTING_ID).remarks).to be_nil
  end

  it "行が無ければ :not_found" do
    expect(update.call(MISSING_ID, { city: "千代田区" }).status).to eq :not_found
  end

  it "ID の形がおかしければ :not_found" do
    expect(update.call("bad", { city: "千代田区" }).status).to eq :not_found
  end
end
