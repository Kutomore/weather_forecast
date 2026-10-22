# Weather Forecast

A Rails 8 app that shows the weather forecast for a US ZIP code: the current temperature, today's high and low, and a 7-day forecast. Forecasts are cached per ZIP code for 30 minutes, and the page shows when a result came from the cache.

## Running locally

**Requirements:** Docker with Docker Compose v2.

```sh
git clone https://github.com/kutomore/weather_forecast.git
cd weather_forecast
docker compose up
```

Then open http://localhost:3000 and enter a ZIP code (for example `95014`). Search the same ZIP again to see the "Cached result" indicator.


**Tests:**

```sh
docker compose run --rm web bundle exec rspec
```

**Linting and security checks**:

```sh
docker compose run --rm web bin/rubocop
docker compose run --rm web bin/brakeman
```

## Approach

The requirements boil down to: take an address, find its ZIP code, fetch a forecast, and cache it by ZIP for 30 minutes. I treated the ZIP code as the core of the design, because both the forecast and the cache are scoped by it:

1. The user enters a ZIP code. The form validates the format in the browser, and the server validates it again.
2. On a cache miss, the app looks up the ZIP's coordinates and place name ([Zippopotam.us](https://zippopotam.us/)), then fetches the forecast for those coordinates ([Open-Meteo](https://open-meteo.com/)).
3. The result is cached under the ZIP code, so every later lookup of that ZIP within 30 minutes makes no external calls at all.

## Architecture

```
GET /?zip=95014
 └─ ForecastsController#show      reads the param, renders the result or the error
     └─ GetForecastService        validates the ZIP, caches by ZIP, builds the Forecast
         ├─ ZippopotamClient      ZIP → place name and coordinates
         ├─ OpenMeteoClient       coordinates → current temperature, daily highs and lows
         └─ (both use) JsonHttp   GET with timeouts, JSON parsing, a single error type
```

| Piece | Location | Responsibility |
|---|---|---|
| `ForecastsController` | `app/controllers` | One `show` action. Calls the service when a ZIP is present and turns service errors into a message. |
| `GetForecastService` | `app/services` | ZIP validation and normalization, caching, and assembling the result. The only place that knows the business rules. |
| `ZippopotamClient`, `OpenMeteoClient` | `lib/` | One class per external API. They know URLs, parameters and response formats, and return plain Ruby hashes. |
| `JsonHttp` | `lib/` | Generic HTTP helper. A 404 returns `nil` ("not found"), and every other network, status or parsing failure becomes `JsonHttp::Error`. |
| `Forecast`, `Forecast::Day` | `app/models` | Immutable value objects (`Data.define`), not database models. The view only ever sees these. |
| `forecasts/show`, `forecasts/_forecast` | `app/views` | The form, and the result rendered inside a Turbo Frame. |

## Decisions and why

**ZIP code as the only input.** The requirements ask for an address but scope both the forecast and the cache to the ZIP code. I started with street, city and country fields, then removed them: the backend never used them, and they made the form longer without changing the result. Parsing a free-text address was the alternative, but it's error-prone and would require geocoding on every request just to find the cache key. ZIP+4 is accepted and trimmed to 5 digits, so `95014-2083` and `95014` share a cache entry.

**US only.** Postal codes aren't unique across countries (`75001` is both Paris and Addison, TX), so supporting other countries means adding a country to the input and to the cache key. I kept the scope to US ZIP codes and listed international support under next steps. Temperatures are in Fahrenheit for the same reason.

**A ZIP-specific lookup instead of a general geocoder.** Zippopotam.us maps a ZIP code to its place name and coordinates, using USPS ZIP data from GeoNames. I started with Nominatim (OpenStreetMap) and switched after finding ZIP codes it couldn't resolve (see [Challenges](#challenges)). Looking up the ZIP itself, rather than a street address, also keeps the cache consistent: everyone who searches a ZIP gets the forecast for that ZIP's location.

**Zippopotam and Open-Meteo.** Both are free and need no API key, so the app runs with `docker compose up` and no setup. I also considered weather APIs that accept an address or ZIP directly (OpenWeatherMap, Visual Crossing, WeatherAPI). They would save one call, but they all need an API key, which every reviewer would have to create before the app could start. Since both calls only happen on a cache miss, the second call costs little.

**Caching the external calls, not the page.** The cache wraps the two API calls (`Rails.cache.fetch`, keyed by ZIP), which are the slow and rate-limited part. I ruled out the other Rails caching options:
- Fragment caching only saves template rendering, which is already cheap.
- HTTP caching (`expires_in`, ETags) is stored in each user's browser, so one user's lookup doesn't speed up anyone else's unless a CDN sits in front of the app.
- Action caching has been removed from Rails core (it now lives in a separate gem), and it's keyed by the URL, so `95014` and `95014-2083` would be cached separately. Caching on the normalized ZIP avoids that.
- A cached page can't say whether it came from the cache.

The "cached" flag is set for each request rather than stored in the cache, and failed lookups are never cached, so the next request simply retries.

**Solid Cache on SQLite instead of Redis.** I chose SQLite for simplicity, and Solid Cache (the Rails 8 default) follows the same idea: no extra service to run. Development uses the same cache store as production, so caching behaves the same while developing and demoing. The app's code only uses the `Rails.cache` API, so moving to Redis or another database is a configuration change.

**Hotwire instead of a JavaScript framework.** The UI is one form and one result. A Turbo Frame swaps in only the result area with no full page reload, and the URL updates (`/?zip=95014`), so results can be bookmarked and survive a refresh. There's no custom JavaScript and no JS build step. A separate React frontend would add an API layer and a build pipeline without any benefit to the user here.

**Standard library for HTTP.** The app makes two GET requests, so `Net::HTTP` is enough and I didn't add Faraday or HTTParty. `JsonHttp` sets 5-second timeouts, because the default of 60 seconds would leave the page hanging when an API is down.

**API clients in `lib/`, value objects in `app/models`.** The clients return plain hashes, so code in `lib/` has no dependency on app classes. The service maps those hashes into `Forecast` objects. Swapping a provider means replacing one client, without touching the service or the view.

**Rails setup.** I kept Rails defaults except where they didn't fit: RSpec instead of Minitest, and generated without Action Mailbox, Action Text, Active Storage, Action Cable, Kamal and Thruster, because the app doesn't use them. Development runs in Docker Compose (`Dockerfile.dev`). The generated production `Dockerfile` is unchanged.

## Testing

All specs stub the external APIs with WebMock, which also blocks any real HTTP call, so the suite runs offline and gives the same result every time.

| Layer | Spec | What it covers |
|---|---|---|
| HTTP and API clients | `spec/lib` | Exact request parameters, response mapping, a 404 meaning "not found", and every other failure (error status, timeout, refused connection, invalid JSON) becoming `JsonHttp::Error`. |
| Service | `spec/services` | ZIP validation and ZIP+4 handling, unknown ZIPs, cache hits making no API calls, and failures not being cached. |
| Controller and view | `spec/requests` | No lookup without a ZIP, rendering of the forecast and the cache indicator, and each error message. The service is stubbed here, because the layers below have their own specs. |
| End to end | `spec/system` | A user enters a ZIP, sees the forecast, searches again and sees "Cached result", through the real service and clients. |

The test environment normally uses `:null_store`, so specs tagged `:caching` get a real in-memory cache.

## Challenges

- **Turning an address into a ZIP code reliably.** Free-text addresses are ambiguous, which is what led to the ZIP-only input.
- **Valid ZIP codes that weren't found.** I first built the lookup on Nominatim (OpenStreetMap). During final testing, some ZIP codes that should have worked showed "Couldn't find that ZIP code", for example `88595` in El Paso, TX. After investigating, I found the cause was a limitation of Nominatim's data rather than a bug in the app: OpenStreetMap only knows a postcode if a mapped address uses it, and PO-box-only ZIP codes like `88595` have no street addresses. Rural ZIPs had a related gap, since some only had a county and no town name. I decided to switch to Zippopotam.us, which is built on USPS ZIP data. It found every ZIP I tested, including PO-box ZIPs, and returns the town name directly (`99723` became "Barrow, AK" instead of "North Slope Borough, AK"). Because each API has its own client, the switch only replaced one class; the service, the view and the rest of the tests didn't change.

## Known limitations

- **Zippopotam.us is a free community service with no uptime guarantee.** For production I'd use a paid provider with an SLA. Since a ZIP's coordinates almost never change, I'd also cache ZIP lookups much longer than forecasts (days instead of 30 minutes), so a geocoder outage would only affect ZIPs never seen before.
- **A ZIP code gets one forecast for its center point.** That's what the requirements ask for, and weather rarely varies much within a ZIP, but very large rural ZIP codes can span different conditions.
- **"Current" temperatures can be up to 30 minutes old** when served from the cache. The page shows when the data was fetched.
- **Styling is minimal,** following the "functionality is a priority over form" guideline.

## Next steps

- **International postal codes.** Zippopotam.us covers around 60 countries and Open-Meteo works worldwide. This needs a country field in the form and the country in the cache key.
- **Search by place name** ("Madrid", "Lisbon") and places without postal codes. This needs free-text geocoding with autocomplete, forecasts cached by rounded coordinates (which matches Open-Meteo's forecast grid), and geocoding results cached separately.
- **"Use my location" button.** Browser geolocation only returns coordinates, so a small Stimulus controller would reverse-geocode them (Nominatim's reverse lookup works well for this) and fill in the ZIP. I built it, then removed it: it wasn't required, and testing it properly needs a headless browser in the test setup.
- **Weather conditions and hourly forecasts.** Open-Meteo already provides weather codes for icons and hourly data. This means extending the client, the `Forecast` object and the view.
- **Resilience.** Retries with backoff for temporary API errors, and serving a slightly stale cached forecast when an API is down.
- **Styling** and a unit toggle between °F and °C.
