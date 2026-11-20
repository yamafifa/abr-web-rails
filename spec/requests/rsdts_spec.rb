require "rails_helper"

RSpec.describe "住居の画面", type: :request do
  describe "GET /（一覧）" do
    it "全件の件数と、1 ページ 15 件を表示する" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1,752,573")
      expect(response.body.scan(%r{/rsdt/[0-9_]+/edit}).size).to eq 15
    end

    it "検索条件と件数で絞り込み、条件をフォームに残す" do
      get root_path, params: { town: "上北沢", chome: "3", blk: "1", per: "30" }
      expect(response.body).to include(">21</span> 件")
      expect(response.body).to include('value="上北沢"')
      expect(response.body.scan(%r{/rsdt/[0-9_]+/edit}).size).to eq 21
    end

    it "編集・削除のリンクに、今の条件を戻り先として付ける" do
      get root_path, params: { town: "上北沢", chome: "3", blk: "1", page: "2", per: "15" }
      expect(response.body).to include("back=%2F%3Fblk%3D1%26chome%3D3%26page%3D2%26town%3D")
    end
  end

  describe "GET /rsdt/:id/edit" do
    it "今の値を表示する" do
      get edit_rsdt_path(EXISTING_ID)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="千代田区"', 'value="1947-04-17"')
    end

    it "無ければ 404" do
      get edit_rsdt_path(MISSING_ID)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /rsdt/:id" do
    let(:rsdt) { Rsdt.find_by_param(EXISTING_ID) }

    it "更新して、戻り先へ 303 で redirect する" do
      patch rsdt_path(EXISTING_ID, back: "/?page=2"), params: { rsdt: input_of(rsdt, remarks: "テスト") }
      expect(response).to redirect_to("/?page=2")
      expect(response).to have_http_status(:see_other)
      expect(flash[:notice]).to eq "更新しました"
      expect(Rsdt.find_by_param(EXISTING_ID).remarks).to eq "テスト"
    end

    it "入力が正しくなければ 422 で、エラーと入力した値を表示する" do
      patch rsdt_path(EXISTING_ID), params: { rsdt: input_of(rsdt, city: "", efct_date: "2026-02-30") }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("必須です", 'value="2026-02-30"')
    end

    it "行が無ければ、戻り先へ redirect してお知らせを出す" do
      patch rsdt_path(MISSING_ID), params: { rsdt: { city: "千代田区" } }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq "この行はすでに削除されています"
    end

    it "主キーは受け取らない" do
      patch rsdt_path(EXISTING_ID), params: { rsdt: input_of(rsdt).merge(lg_code: "999999") }
      expect(Rsdt.find_by_param(EXISTING_ID)).to be_present
    end
  end

  describe "DELETE /rsdt/:id" do
    it "削除して、戻り先へ redirect する" do
      delete rsdt_path(EXISTING_ID, back: "/?town=x")
      expect(response).to redirect_to("/?town=x")
      expect(flash[:notice]).to eq "削除しました"
      expect(Rsdt.find_by_param(EXISTING_ID)).to be_nil
    end

    %w[//evil.example https://evil.example javascript:alert(1)].each do |back|
      it "戻り先が外のサイトなら / にする（#{back}）" do
        delete rsdt_path(MISSING_ID, back:)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
