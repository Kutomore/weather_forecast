class ZippopotamClient
  URL = "https://api.zippopotam.us/us"

  # Returns { name:, state:, lat:, lon: } for a US ZIP code, or nil when the ZIP doesn't exist.
  # The ZIP goes into the URL path, so callers must validate it first.
  def self.find_zip(zip)
    json = JsonHttp.get("#{URL}/#{zip}") or return
    place = json["places"].first

    { name: place["place name"], state: place["state abbreviation"], lat: place["latitude"], lon: place["longitude"] }
  end
end
