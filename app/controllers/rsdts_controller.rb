# 画面からの操作を受け取る
# ここでやるのは「パラメーターを読む → ユースケースを呼ぶ → 表示・redirect」だけ
class RsdtsController < ApplicationController
  include BackUrl

  def index
    @query = RsdtListQuery.from_params(params)
    @result = SearchRsdt.new.call(criteria: @query.criteria, page: @query.page, per_page: @query.per_page)
    # 編集・削除のあとに戻ってくる URL（今の検索条件とページ）
    @back = root_path(@query.with(page: @result.page).to_params)
  end

  def edit
    @back = safe_back(params[:back])
    @rsdt = GetRsdt.new.call(params[:id])
    render_not_found unless @rsdt
  end

  def update
    @back = safe_back(params[:back])
    result = UpdateRsdt.new.call(params[:id], rsdt_input)
    case result.status
    when :updated
      redirect_to @back, notice: "更新しました", status: :see_other
    when :not_found
      redirect_to @back, alert: "この行はすでに削除されています", status: :see_other
    when :invalid
      @rsdt = result.rsdt
      flash.now[:alert] = "入力内容を確認してください"
      # Turbo は、フォームの送信に HTML を返すとき 4xx か 5xx でないと画面を差し替えない
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    DeleteRsdt.new.call(params[:id])
    redirect_to safe_back(params[:back]), notice: "削除しました", status: :see_other
  end

  private

  # 主キー以外の 17 列だけを受け取る
  def rsdt_input
    params.fetch(:rsdt, {}).permit(*Rsdt::EDITABLE_ATTRIBUTES).to_h.symbolize_keys
  end

  def render_not_found
    render :not_found, status: :not_found
  end
end
