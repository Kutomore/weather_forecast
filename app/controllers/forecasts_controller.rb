class ForecastsController < ApplicationController
  def show
    return if params[:zip].blank?

    @forecast = GetForecastService.call(zip: params[:zip])
  rescue GetForecastService::Error => e
    @error = e.message
  end
end
