require "rails_helper"

RSpec.describe "Looking up a forecast", type: :system, caching: true do
  before do
    driven_by :rack_test
    stub_zippopotam
    stub_open_meteo
  end

  it "shows the forecast and flags repeat lookups as cached" do
    visit root_path
    fill_in "ZIP code", with: "95014"
    click_on "Get forecast"

    expect(page).to have_content("Cupertino, CA 95014")
    expect(page).to have_content("57°F")
    expect(page).to have_content("High 60° · Low 56°")
    expect(page).to have_no_content("Cached result")

    click_on "Get forecast"

    expect(page).to have_content("Cached result")
  end

  it "shows an error for a ZIP that doesn't exist" do
    stub_unknown_zip("00000")

    visit root_path
    fill_in "ZIP code", with: "00000"
    click_on "Get forecast"

    expect(page).to have_content("Couldn't find that ZIP code.")
  end
end
