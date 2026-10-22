class ForecastsController < ApplicationController
  def show
    @zip = params[:zip].presence || cookies[:last_zip]
    return if @zip.blank?

    @forecast = GetForecastService.call(zip: @zip)
    cookies[:last_zip] = { value: @zip, expires: 1.year }
  rescue GetForecastService::Error => e
    @error = e.message
  end
end
