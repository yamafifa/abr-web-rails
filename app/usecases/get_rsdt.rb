# 住居を 1 件取る。無ければ nil
class GetRsdt
  def call(id_param)
    Rsdt.find_by_param(id_param)
  end
end
