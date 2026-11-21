require "net/http"

# Elasticsearch の REST API を呼ぶ（gem は入れず、Ruby 標準の Net::HTTP を使う）
# 接続先は環境変数 ES_URL。無ければ abr-batch の compose.yaml の http://127.0.0.1:9200
class EsClient
  # 接続できない・エラーが返ったとき
  class Error < StandardError; end
  # 404（インデックスが無いなど）
  class NotFound < Error; end

  def initialize(url: ENV.fetch("ES_URL", "http://127.0.0.1:9200"))
    @uri = URI(url)
  end

  def post(path, body) = request(Net::HTTP::Post.new(path, "Content-Type" => "application/json"), body.to_json)
  def get(path) = request(Net::HTTP::Get.new(path))

  private

  def request(req, body = nil)
    req.body = body if body
    res = Net::HTTP.start(@uri.host, @uri.port, open_timeout: 2, read_timeout: 10) { it.request(req) }
    raise NotFound, "Elasticsearch が 404 を返しました（#{req.path}）" if res.is_a?(Net::HTTPNotFound)
    raise Error, "Elasticsearch が #{res.code} を返しました: #{res.body.to_s[0, 300]}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  rescue SystemCallError, IOError, Timeout::Error, SocketError => e
    raise Error, "Elasticsearch に接続できません（#{@uri}）: #{e.message}"
  end
end
