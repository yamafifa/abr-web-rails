# 住居を削除する。すでに無ければ、消せたものとして扱う（同じ削除を 2 回送られても失敗にしない）
class DeleteRsdt
  def call(id_param)
    key = Rsdt.key_from_param(id_param)
    Rsdt.where(key).delete_all if key
    nil
  end
end
