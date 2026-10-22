require "rails_helper"

RSpec.describe GetForecastService, :caching do
  subject(:forecast) { described_class.call(zip:) }

  let(:zip) { "95014" }
  let(:any_nominatim_request) { a_request(:get, NominatimClient::URL).with(query: hash_including({})) }
  let(:any_open_meteo_request) { a_request(:get, OpenMeteoClient::URL).with(query: hash_including({})) }

  before do
    stub_nominatim
    stub_open_meteo
  end

  describe ".call" do
    it "geocodes the ZIP and returns its forecast" do
      expect(forecast).to have_attributes(location: "Cupertino, CA 95014", current_temp: 57.4,
                                          high: 60.2, low: 55.8, cached: false)
      expect(forecast.daily).to eq([
        Forecast::Day.new(date: Date.new(2026, 10, 22), high: 60.2, low: 55.8),
        Forecast::Day.new(date: Date.new(2026, 10, 23), high: 66.1, low: 53.0)
      ])
    end

    context "when the ZIP was looked up before" do
      before { described_class.call(zip: "95014") }

      it "serves the forecast from the cache without calling the APIs again" do
        expect(forecast.cached).to be(true)
        expect(any_nominatim_request).to have_been_made.once
        expect(any_open_meteo_request).to have_been_made.once
      end

      context "as a ZIP+4" do
        let(:zip) { " 95014-2083 " }

        it "shares the same cache entry" do
          expect(forecast.cached).to be(true)
        end
      end
    end

    context "with a ZIP outside a city" do
      let(:zip) { "99723" }

      before do
        rural = WeatherApiStubs::CUPERTINO.merge(
          "address" => { "postcode" => "99723", "county" => "North Slope Borough", "ISO3166-2-lvl4" => "US-AK" }
        )
        stub_nominatim(zip:, results: [ rural ])
      end

      it "falls back to the county for the location" do
        expect(forecast.location).to eq("North Slope Borough, AK 99723")
      end
    end

    context "with a malformed ZIP" do
      let(:zip) { "9501" }

      it "raises InvalidZip without calling the APIs" do
        expect { forecast }.to raise_error(described_class::InvalidZip)
        expect(any_nominatim_request).not_to have_been_made
      end
    end

    context "with a ZIP that doesn't exist" do
      let(:zip) { "00000" }

      before { stub_nominatim(zip:, results: []) }

      it "raises AddressNotFound" do
        expect { forecast }.to raise_error(described_class::AddressNotFound)
      end
    end

    context "when an API times out" do
      before { stub_request(:get, NominatimClient::URL).with(query: hash_including({})).to_timeout }

      it "raises Error" do
        expect { forecast }.to raise_error(described_class::Error)
      end
    end

    context "when an API fails once" do
      before do
        stub_request(:get, OpenMeteoClient::URL).with(query: hash_including({}))
          .to_return(status: 503).then
          .to_return_json(body: WeatherApiStubs::FORECAST)
      end

      it "doesn't cache the failure, so the next lookup retries" do
        expect { described_class.call(zip:) }.to raise_error(described_class::Error)
        expect(forecast.cached).to be(false)
      end
    end
  end
end
