module WeatherApiStubs
  CUPERTINO = {
    "post code" => "95014",
    "country" => "United States",
    "country abbreviation" => "US",
    "places" => [
      { "place name" => "Cupertino", "state" => "California", "state abbreviation" => "CA",
        "latitude" => "37.318", "longitude" => "-122.0449" }
    ]
  }.freeze

  FORECAST = {
    "current" => { "temperature_2m" => 57.4 },
    "daily" => {
      "time" => %w[2026-10-22 2026-10-23],
      "temperature_2m_max" => [ 60.2, 66.1 ],
      "temperature_2m_min" => [ 55.8, 53.0 ]
    }
  }.freeze

  def stub_zippopotam(zip: "95014", body: CUPERTINO)
    stub_request(:get, "#{ZippopotamClient::URL}/#{zip}").to_return_json(body:)
  end

  # Zippopotam answers unknown ZIPs with a 404 and an empty JSON object
  def stub_unknown_zip(zip)
    stub_request(:get, "#{ZippopotamClient::URL}/#{zip}").to_return(status: 404, body: "{}")
  end

  def stub_open_meteo(lat: "37.318", lon: "-122.0449")
    stub_request(:get, OpenMeteoClient::URL)
      .with(query: hash_including("latitude" => lat, "longitude" => lon, "temperature_unit" => "fahrenheit"))
      .to_return_json(body: FORECAST)
  end
end

RSpec.configure do |config|
  config.include WeatherApiStubs
end
