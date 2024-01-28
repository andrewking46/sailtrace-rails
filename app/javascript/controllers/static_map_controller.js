import { Controller } from "@hotwired/stimulus";
import L from "leaflet";

export default class extends Controller {
  static values = {
    recordingId: Number,
    boatColor: String
  };

  connect() {
    this.initializeStaticMap();
  }

  initializeStaticMap() {
    const map = L.map(this.element, {
      center: [0, 0], // Will be set dynamically
      zoom: 13,
      zoomControl: false,
      touchZoom: false,
      scrollWheelZoom: false,
      doubleClickZoom: false,
      dragging: false,
      keyboard: false
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map);

    fetch(`/recordings/${this.recordingIdValue}/recorded_locations.json`)
      .then(response => response.json())
      .then(locations => {
        this.drawColoredPath(map, locations);
      })
      .catch(error => console.log(error));
  }

  drawColoredPath(map, locations) {
    locations.forEach((location, index) => {
      if (index === 0) return;
      const prevLocation = locations[index - 1];
      const color = this.getSegmentColor(prevLocation, location);

      L.polyline([
        [prevLocation.latitude, prevLocation.longitude],
        [location.latitude, location.longitude]
      ], { color, weight: 3 }).addTo(map);
    });

    if (locations.length > 0) {
      map.fitBounds(L.polyline(locations.map(loc => [loc.latitude, loc.longitude])).getBounds());
    }
  }

  getSegmentColor(prevLocation, location) {
    const distance = this.calculateDistance(
      prevLocation.latitude, prevLocation.longitude,
      location.latitude, location.longitude
    );

    const timeElapsed = (new Date(location.created_at) - new Date(prevLocation.created_at)) / 1000;
    const speed = distance / timeElapsed;

    return speed > 1.4 ? 'green' : speed > 0.7 ? 'yellow' : 'orange';
  }

  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // in meters
  }

  goToReplay(event) {
    event.preventDefault();
    window.location.href = this.data.get("replayPath");
  }
}
