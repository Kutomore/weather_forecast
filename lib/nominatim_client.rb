class NominatimClient
  URL = "https://nominatim.openstreetmap.org/search"
  USER_AGENT = "weather_forecast (https://github.com/kutomore/weather_forecast)"

  def self.find_zip(zip)
    JsonHttp.get(URL, { postalcode: zip, countrycodes: "us", format: "jsonv2", limit: 1, addressdetails: 1 }, "User-Agent" => USER_AGENT).first
  end
end
