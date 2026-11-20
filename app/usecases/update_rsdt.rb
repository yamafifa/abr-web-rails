# 入力を検査して、住居の主キー以外の列を更新する
class UpdateRsdt
  # status: :updated / :invalid / :not_found。:invalid のとき rsdt に入力値とエラーが入っている
  Result = Data.define(:status, :rsdt)

  # input は列名 → 文字列。無い列は空文字（＝ NULL）として扱う
  def call(id_param, input)
    key = Rsdt.key_from_param(id_param)
    return Result.new(status: :not_found, rsdt: nil) unless key

    Rsdt.transaction do
      # 読んでから更新するまでの間に、ほかの画面で消されないように行をロックする
      # （Active Record の save は、行が消えていても成功扱いになるため）
      rsdt = Rsdt.lock.find_by(key)
      return Result.new(status: :not_found, rsdt: nil) unless rsdt

      rsdt.assign_attributes(Rsdt::EDITABLE_ATTRIBUTES.index_with { input[it].to_s })
      rsdt.save ? Result.new(status: :updated, rsdt:) : Result.new(status: :invalid, rsdt:)
    end
  end
end
