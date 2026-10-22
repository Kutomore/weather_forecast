# Weather Forecast

Rails 8 app that looks up a weather forecast for an address, caching results by zip code for 30 minutes.

## Running

Requires Docker.

```sh
docker compose up
```

App: http://localhost:3000. SQLite databases live in `storage/`; `Rails.cache` uses Solid Cache in its own SQLite database.

Tests:

```sh
docker compose run --rm web bundle exec rspec
```

## Scope

- **US only.** The input is a 5-digit ZIP code (ZIP+4 is accepted and trimmed to 5 digits). Forecasts are fetched and cached per ZIP code, as the requirements specify, so every address in a ZIP code shares one forecast.
- **No API keys.** Geocoding uses [Nominatim](https://nominatim.org/) (OpenStreetMap) and forecasts use [Open-Meteo](https://open-meteo.com/), so the app runs with `docker compose up` and no setup.

## Possible extensions

- **International postal codes.** Nominatim and Open-Meteo both work worldwide. Supporting other countries means adding a country field and including it in the cache key, since postal codes aren't unique across countries (`75001` is both Paris and Addison, TX).
- **Search by place name** ("Madrid", "Lisbon") and places without postal codes. This would need free-text geocoding with autocomplete, forecasts cached by rounded coordinates (which matches Open-Meteo's forecast grid), and geocoding results cached separately.
- **"Use my location" button.** Browser geolocation only returns coordinates, so a small Stimulus controller would reverse-geocode them with Nominatim and fill in the ZIP. It was left out to keep the scope tight, and because testing it needs a headless browser in the test setup.
