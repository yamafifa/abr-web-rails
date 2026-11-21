# Elasticsearch で検索するときに、文字をそろえる
#
# MySQL のテーブルは utf8mb4_unicode_ci なので、LIKE や = は次の違いを同じ文字として扱う。
# Elasticsearch の wildcard 型は文字をそのまま比べるので、入れる側（abr-batch）と検索する側（ここ）の両方でそろえる。
# - 全角と半角（「3」で「３丁目」が見つかる）、大文字と小文字 → NFKC ＋ 小文字
# - 濁点・半濁点（「は」と「パ」）→ NFD に分けて、濁点・半濁点の記号を消す
# - カタカナとひらがな（「あ」と「ア」）→ ひらがなにする
# - 小さい仮名（「ヶ」と「ケ」）→ 大きい仮名にする
# CJK 互換漢字（例：U+FA10 の「塚」）はそのまま残す（MySQL は U+585A の「塚」と別の文字として扱うため）
#
# abr-batch の src/lib/fold.ts、Laravel 版・Symfony 版の App\Support\RsdtFold、Java 版の RsdtFold、TS 版の fold.ts と同じ処理。直すときはすべてを直す
module RsdtFold
  # 濁点・半濁点（結合文字 U+3099・U+309A）
  VOICED_MARKS = [ 0x3099, 0x309A ].pack("U*").freeze
  # CJK 互換漢字（U+F900〜U+FAFF、U+2F800〜U+2FA1F）以外の並び
  NOT_CJK_COMPAT = Regexp.new("[^#{[ 0xF900 ].pack('U')}-#{[ 0xFAFF ].pack('U')}#{[ 0x2F800 ].pack('U')}-#{[ 0x2FA1F ].pack('U')}]+")

  def self.call(str)
    str.to_s.gsub(NOT_CJK_COMPAT) { fold_part(it) }
  end

  def self.fold_part(str)
    str.unicode_normalize(:nfkc).downcase
       .unicode_normalize(:nfd).delete(VOICED_MARKS)
       .tr("ァ-ヶ", "ぁ-ゖ")
       .tr("ぁぃぅぇぉっゃゅょゎゕゖ", "あいうえおつやゆよわかけ")
  end
  private_class_method :fold_part
end
