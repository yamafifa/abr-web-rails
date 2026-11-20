# 住居の検索条件。空文字の条件は使わない
# - city: city・ward の部分一致
# - town: oaza_cho・koaza の部分一致
# - chome: chome の部分一致
# - blk_num・rsdt_num: 完全一致
RsdtSearchCriteria = Data.define(:city, :town, :chome, :blk_num, :rsdt_num) do
  def self.empty = new(city: "", town: "", chome: "", blk_num: "", rsdt_num: "")
end
