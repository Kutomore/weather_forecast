module WeatherApiStubs
  CUPERTINO = {
    "lat" => "37.3230",
    "lon" => "-122.0322",
    "display_name" => "95014, Cupertino, Santa Clara County, California, United States",
    "address" => {
      "postcode" => "95014", "city" => "Cupertino", "county" => "Santa Clara County",
      "state" => "California", "ISO3166-2-lvl4" => "US-CA", "country_code" => "us"
    }
  }.freeze

  FORECAST = {
    "current" => { "temperature_2m" => 57.4 },
    "daily" => {
      "time" => %w[2026-10-22 2026-10-23],
      "temperature_2m_max" => [ 60.2, 66.1 ],
      "temperature_2m_min" => [ 55.8, 53.0 ]
    }
  }.freeze

  def stub_nominatim(zip: "95014", results: [ CUPERTINO ])
    stub_request(:get, NominatimClient::URL)
      .with(query: hash_including("postalcode" => zip, "countrycodes" => "us"),
            headers: { "User-Agent" => NominatimClient::USER_AGENT })
      .to_return_json(body: results)
  end

  def stub_open_meteo(lat: CUPERTINO["lat"], lon: CUPERTINO["lon"])
    stub_request(:get, OpenMeteoClient::URL)
      .with(query: hash_including("latitude" => lat, "longitude" => lon, "temperature_unit" => "fahrenheit"))
      .to_return_json(body: FORECAST)
  end
end

RSpec.configure do |config|
  config.include WeatherApiStubs
end
