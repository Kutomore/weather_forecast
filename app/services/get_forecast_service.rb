class GetForecastService < ApplicationService
  class Error < StandardError; end
  class AddressNotFound < Error; end
  class InvalidZip < Error; end

  ZIP_FORMAT = /\A(\d{5})(-\d{4})?\z/
  CACHE_TTL = 30.minutes
  GEOCODE_URL = "https://nominatim.openstreetmap.org/search"
  WEATHER_URL = "https://api.open-meteo.com/v1/forecast"
  USER_AGENT = "weather_forecast (https://github.com/kutomore/weather_forecast)"

  def initialize(zip:)
    @zip = zip.to_s.strip[ZIP_FORMAT, 1] or raise InvalidZip, "Enter a 5-digit ZIP code."
  end

  def call
    cached = true
    forecast = Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      cached = false
      fetch_forecast
    end
    forecast.with(cached:)
  end

  private

  attr_reader :zip

  def cache_key = "forecast/v1/us/#{zip.upcase.delete(' ')}"

  def fetch_forecast
    place = NominatimClient.find_zip(zip) or raise AddressNotFound, "Couldn't find that ZIP code."
    weather = OpenMeteoClient.forecast(place["lat"], place["lon"])
    today = weather[:days].first

    Forecast.new(location: place["display_name"], current_temp: weather[:current_temp],
                high: today.high, low: today.low, daily: weather[:days],
                fetched_at: Time.current, cached: false)
  rescue JsonHttp::Error => e
    Rails.logger.warn("Forecast lookup failed: #{e.message}")
    raise Error, "Forecast service unavailable, try again later."
  end
end
