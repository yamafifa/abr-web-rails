require "rails_helper"

RSpec.describe "Elasticsearch 検索の画面", type: :request do
  it "件数と 1 ページ分、次へ・最後へのリンクを表示する" do
    get es_rsdts_path, params: { town: "上北沢", chome: "3", blk: "1" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(">21</span> 件", "1–15 件目", "after=131121_0001003_001_015_", "last=1")
    expect(response.body.scan(%r{/rsdt/[0-9_]+/edit}).size).to eq 15
  end

  it "編集・削除のリンクに、今の URL を戻り先として付ける" do
    get es_rsdts_path, params: { town: "上北沢", chome: "3", blk: "1", after: "131121_0001003_001_015_" }
    expect(response.body).to include("16–21 件目", "back=%2Fes%3Fafter%3D131121_0001003_001_015_")
  end

  it "同じ条件の DB 検索へのリンクがあり、DB 検索からも戻れる" do
    get es_rsdts_path, params: { town: "上北沢" }
    expect(response.body).to include('href="/?town=%E4%B8%8A%E5%8C%97%E6%B2%A2"')
    get root_path, params: { town: "上北沢" }
    expect(response.body).to include('href="/es?town=%E4%B8%8A%E5%8C%97%E6%B2%A2"')
  end
end
