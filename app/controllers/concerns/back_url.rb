# 編集・削除のあとに戻る URL を扱う
module BackUrl
  extend ActiveSupport::Concern

  private

  # 戻り先は、このサイトの中のパスだけを許す（外のサイトへ飛ばされないように）
  def safe_back(back)
    back.is_a?(String) && back.start_with?("/") && !back.start_with?("//") ? back : root_path
  end
end
