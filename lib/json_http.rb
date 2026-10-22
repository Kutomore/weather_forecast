require "net/http"

module JsonHttp
  class Error < StandardError; end

  # Returns the parsed JSON, or nil for a 404 so callers can treat it as "not found" rather than a failure.
  def self.get(url, params = {}, headers = {})
    uri = URI(url)
    uri.query = URI.encode_www_form(params) if params.any?
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.get(uri.request_uri, headers)
    end
    return if response.is_a?(Net::HTTPNotFound)
    raise Error, "#{uri.host} responded #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => e
    raise Error, "#{uri.host}: #{e.message}"
  end
end
