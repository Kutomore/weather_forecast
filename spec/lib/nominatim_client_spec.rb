require "rails_helper"

RSpec.describe NominatimClient do
  describe ".find_zip" do
    subject(:place) { described_class.find_zip("95014") }

    let!(:search) do
      stub_request(:get, described_class::URL)
        .with(query: { postalcode: "95014", countrycodes: "us", format: "jsonv2", limit: "1", addressdetails: "1" },
              headers: { "User-Agent" => described_class::USER_AGENT })
        .to_return_json(body: results)
    end

    context "when the ZIP exists" do
      let(:results) { [ WeatherApiStubs::CUPERTINO ] }

      it "searches US postal codes with an identifying User-Agent and returns the first match" do
        expect(place).to eq(WeatherApiStubs::CUPERTINO)
        expect(search).to have_been_requested.once
      end
    end

    context "when the ZIP doesn't exist" do
      let(:results) { [] }

      it "returns nil" do
        expect(place).to be_nil
      end
    end
  end
end
