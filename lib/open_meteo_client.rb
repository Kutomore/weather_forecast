class OpenMeteoClient
  URL = "https://api.open-meteo.com/v1/forecast"

  def self.forecast(lat, lon)
    json = JsonHttp.get(URL, latitude: lat, longitude: lon, timezone: "auto", temperature_unit: "fahrenheit",
                             current: "temperature_2m", daily: "temperature_2m_max,temperature_2m_min")
    daily = json["daily"]
    days = daily["time"].zip(daily["temperature_2m_max"], daily["temperature_2m_min"]).map do |date, high, low|
      { date: Date.parse(date), high:, low: }
    end

    { current_temp: json.dig("current", "temperature_2m"), days: }
  end
end
