require "rails_helper"

RSpec.describe "Forecasts", type: :request do
  describe "GET /" do
    let(:forecast) do
      Forecast.new(location: "Cupertino, CA 95014", current_temp: 57.4, high: 60.2, low: 55.8,
                   daily: [ Forecast::Day.new(date: Date.new(2026, 10, 22), high: 60.2, low: 55.8) ],
                   fetched_at: Time.current, cached: false)
    end

    context "without a ZIP code" do
      it "renders the form without looking up a forecast" do
        expect(GetForecastService).not_to receive(:call)

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="zip"')
      end
    end

    context "with a ZIP code" do
      it "renders the forecast" do
        allow(GetForecastService).to receive(:call).with(zip: "95014").and_return(forecast)

        get root_path, params: { zip: "95014" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Cupertino, CA 95014", "57°F", "High 60° · Low 56°")
        expect(response.body).not_to include("Cached result")
      end

      it "flags a forecast served from the cache" do
        allow(GetForecastService).to receive(:call).and_return(forecast.with(cached: true))

        get root_path, params: { zip: "95014" }

        expect(response.body).to include("Cached result")
      end
    end

    context "when returning without a ZIP code" do
      it "shows the forecast for the last ZIP looked up" do
        allow(GetForecastService).to receive(:call).with(zip: "95014").and_return(forecast)
        get root_path, params: { zip: "95014" }

        get root_path

        expect(GetForecastService).to have_received(:call).twice
        expect(response.body).to include("Cupertino, CA 95014", 'value="95014"')
      end

      it "doesn't remember a ZIP whose lookup failed" do
        allow(GetForecastService).to receive(:call).and_raise(GetForecastService::AddressNotFound, "Couldn't find that ZIP code.")
        get root_path, params: { zip: "00000" }

        get root_path

        expect(GetForecastService).to have_received(:call).once
      end
    end

    context "when the lookup fails" do
      {
        GetForecastService::InvalidZip => "Enter a 5-digit ZIP code.",
        GetForecastService::AddressNotFound => "Couldn't find that ZIP code.",
        GetForecastService::Error => "Forecast service unavailable, try again later."
      }.each do |error, message|
        it "shows the #{error.name.demodulize} message" do
          allow(GetForecastService).to receive(:call).and_raise(error, message)

          get root_path, params: { zip: "00000" }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(ERB::Util.html_escape(message))
        end
      end
    end
  end
end
