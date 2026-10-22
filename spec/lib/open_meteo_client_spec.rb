require "rails_helper"

RSpec.describe OpenMeteoClient do
  describe ".forecast" do
    subject(:forecast) { described_class.forecast("37.3230", "-122.0322") }

    before do
      stub_request(:get, described_class::URL)
        .with(query: { latitude: "37.3230", longitude: "-122.0322", timezone: "auto", temperature_unit: "fahrenheit",
                       current: "temperature_2m", daily: "temperature_2m_max,temperature_2m_min" })
        .to_return_json(body: WeatherApiStubs::FORECAST)
    end

    it "requests Fahrenheit and maps the response into the current temperature and daily highs and lows" do
      expect(forecast).to eq(
        current_temp: 57.4,
        days: [
          { date: Date.new(2026, 10, 22), high: 60.2, low: 55.8 },
          { date: Date.new(2026, 10, 23), high: 66.1, low: 53.0 }
        ]
      )
    end
  end
end
