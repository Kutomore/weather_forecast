class Forecast < Data.define(:location, :current_temp, :high, :low, :daily, :fetched_at, :cached)
  Day = Data.define(:date, :high, :low)

  def to_partial_path = "forecasts/forecast"
end
