# テストで使う住居。どれも abr-batch で取り込んだ元のデータにある行
# （describe の中から定数として参照できるように、トップレベルに置く。テストのときだけ読み込まれる）
EXISTING_ID = "131016_0001001_006_001_".freeze # 千代田区 内幸町一丁目 6-1
MISSING_ID = "131016_0001001_006_999_99999".freeze # 無い行
KAMIKITAZAWA_3_1 = { town: "上北沢", chome: "3", blk_num: "1" }.freeze # 世田谷区 上北沢３丁目 の blk_num=1（21 件）

module RsdtHelpers
  def criteria(**kw) = RsdtSearchCriteria.empty.with(**kw)

  # 17 列すべての入力（今の値のまま）。一部だけ変えたいときに使う
  def input_of(rsdt, **changes)
    Rsdt::EDITABLE_ATTRIBUTES.index_with { rsdt.read_attribute_before_type_cast(it).to_s }.merge(changes)
  end
end

RSpec.configure { it.include RsdtHelpers }
