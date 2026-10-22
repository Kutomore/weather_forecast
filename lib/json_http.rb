require "net/http"

module JsonHttp
  class Error < StandardError; end

  def self.get(url, params, headers = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.get(uri.request_uri, headers)
    end
    raise Error, "#{uri.host} responded #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => e
    raise Error, "#{uri.host}: #{e.message}"
  end
end
