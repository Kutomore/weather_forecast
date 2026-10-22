require "rails_helper"

RSpec.describe ZippopotamClient do
  describe ".find_zip" do
    subject(:place) { described_class.find_zip(zip) }

    context "when the ZIP exists" do
      let(:zip) { "95014" }

      before { stub_zippopotam }

      it "returns its place name, state and coordinates" do
        expect(place).to eq(name: "Cupertino", state: "CA", lat: "37.318", lon: "-122.0449")
      end
    end

    context "when the ZIP doesn't exist" do
      let(:zip) { "00000" }

      before { stub_unknown_zip(zip) }

      it "returns nil" do
        expect(place).to be_nil
      end
    end
  end
end
