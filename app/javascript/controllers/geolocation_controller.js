import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="geolocation"
export default class extends Controller {
  static targets = ["zip", "button"]

  locate() {
    if (!navigator.geolocation) return alert("Your browser doesn't support geolocation.")

    this.buttonTarget.disabled = true
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => this.fill(coords).finally(() => (this.buttonTarget.disabled = false)),
      () => {
        this.buttonTarget.disabled = false
        alert("Couldn't get your location.")
      },
      { timeout: 10000 }
    )
  }

  async fill({ latitude, longitude }) {
    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${latitude}&lon=${longitude}`
      )
      if (!response.ok) throw new Error(response.statusText)

      const { address } = await response.json()
      if (address.country_code !== "us") return alert("Weather forecast only works inside the US.")

      this.zipTarget.value = address.postcode || ""
    } catch {
      alert("Couldn't look up your address.")
    }
  }
}
