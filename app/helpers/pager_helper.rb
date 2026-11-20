module PagerHelper
  # 表示するページ番号（今のページの前後 2 つと、最初と最後。間は :gap にする）
  def pager_items(page, total_pages)
    pages = ([ 1, total_pages ] + ((page - 2)..(page + 2)).to_a).select { it.between?(1, total_pages) }.uniq.sort
    pages.each_with_index.flat_map do |p, i|
      i.positive? && p - pages[i - 1] > 1 ? [ :gap, p ] : [ p ]
    end
  end
end
