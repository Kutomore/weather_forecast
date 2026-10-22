require "rails_helper"

RSpec.describe JsonHttp do
  describe ".get" do
    subject(:get) { described_class.get(url, { q: "rails", page: 2 }, { "User-Agent" => "spec" }) }

    let(:url) { "https://api.example.com/search" }
    let(:endpoint) { stub_request(:get, url).with(query: { q: "rails", page: "2" }, headers: { "User-Agent" => "spec" }) }

    it "sends the params and headers and returns the parsed JSON" do
      endpoint.to_return_json(body: { results: [ 1, 2 ] })

      expect(get).to eq("results" => [ 1, 2 ])
    end

    context "when the server responds with an error status" do
      before { endpoint.to_return(status: 503) }

      it "raises Error with the host and status" do
        expect { get }.to raise_error(described_class::Error, "api.example.com responded 503")
      end
    end

    context "when the request times out" do
      before { endpoint.to_timeout }

      it "raises Error" do
        expect { get }.to raise_error(described_class::Error, /\Aapi\.example\.com: /)
      end
    end

    context "when the connection fails" do
      before { endpoint.to_raise(Errno::ECONNREFUSED) }

      it "raises Error" do
        expect { get }.to raise_error(described_class::Error, /Connection refused/)
      end
    end

    context "when the body isn't JSON" do
      before { endpoint.to_return(body: "<html>Bad gateway</html>") }

      it "raises Error" do
        expect { get }.to raise_error(described_class::Error)
      end
    end
  end
end
