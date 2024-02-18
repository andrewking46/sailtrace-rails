import { Controller } from "@hotwired/stimulus";
import L from "leaflet";

export default class extends Controller {
  static targets = ["slider", "timeDisplay", "map"];
  static values = { recordingId: Number, raceId: Number, recordingStartedAt: Number, recordingEndedAt: Number };

  connect() {
    this.initializeMap();
    this.fetchRecordingData();
  }

  initializeMap() {
    this.map = L.map(this.mapTarget, {
      center: [0, 0],
      zoom: 13,
      zoomControl: true,
      touchZoom: true,
      scrollWheelZoom: true,
      doubleClickZoom: true,
      dragging: false,
      keyboard: false
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
      noWrap: true
    }).addTo(this.map);
  }

  async fetchRecordingData() {
    this.recordings = []

    try {
      if (Number.isFinite(this.raceIdValue) && this.raceIdValue > 0) {
        const response = await fetch(`/races/${this.raceIdValue}/recordings.json`);
        const recordings = await response.json();
        this.recordings.push(...recordings);
      } else {
        const response = await fetch(`/recordings/${this.recordingIdValue}.json`);
        const recording = await response.json();
        this.recordings.push(recording);
      }
      this.simplifyPaths();
      this.drawPaths(parseInt(this.sliderTarget.value, 10));
      this.centerMap();
    } catch (error) {
      console.error(error);
    }
  }

  simplifyPaths() {
    this.recordings.forEach(recording => {
      const simplifiedPathLocations = this.simplifyPath(recording.recorded_locations, 2);

      recording.simplifiedPathLocations = simplifiedPathLocations;
    })
  }

  // Draw paths for the recording(s)
  drawPaths(time) {
    this.recordings.forEach(recording => {
      this.drawPathUpToTime(recording, time);
    });
  }

  resizeMap() {
    this.map.fitBounds(L.polyline(this.recordings.find((recording) => recording.id = this.recordingIdValue).simplifiedPathLocations.map(positions => [positions.latitude, positions.longitude])).getBounds());
  }

  centerMap() {
    this.map.fitBounds(L.polyline(this.recordings.find((recording) => recording.id = this.recordingIdValue).simplifiedPathLocations.slice(0,4).map(positions => [positions.latitude, positions.longitude])).getBounds());
  }

  drawPathUpToTime(recording, time) {
    this.map.eachLayer(layer => {
      if (!(layer instanceof L.TileLayer)) {
        this.map.removeLayer(layer);
      }
    });

    const validLocations = recording.simplifiedPathLocations.filter((location) => new Date(location.created_at) >= new Date(this.recordingStartedAtValue) && new Date(location.created_at) <= time)

    for (let i = 1; i <= validLocations.length - 1; i++) {
      const previousLocation = validLocations[i - 1];
      const currentLocation = validLocations[i];
      const color = recording.id === this.recordingIdValue ? this.getSegmentColor(previousLocation, currentLocation) : 'white';

      L.polyline([
        [previousLocation.latitude, previousLocation.longitude],
        [currentLocation.latitude, currentLocation.longitude]
      ], { color, weight: 3 }).addTo(this.map);
    }

    if (validLocations.length > 0) {
      this.addBoatMarker(validLocations.at(-1), recording.boat.sail_number, recording.boat.hull_color);
    }
  }

  addBoatMarker(position, sailNumber, color) {
    // Create a custom icon for the boat marker
    const boatIcon = L.divIcon({
      className: 'boat-marker',
      html: `<div style="background-color: ${color};">${sailNumber}</div>`
    });

    // Add the marker to the map at the given position
    L.marker([position.latitude, position.longitude], { icon: boatIcon }).addTo(this.map);

    // L.circleMarker([currentPosition.latitude, currentPosition.longitude], {
    //   radius: 4,
    //   color: this.boatColorValue
    // }).addTo(this.map);
  }

  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // meters
    const φ1 = lat1 * Math.PI / 180; // φ, λ in radians
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // in meters
  }

  getSegmentColor(previousLocation, currentLocation) {
    const distance = this.calculateDistance(
      previousLocation.latitude, previousLocation.longitude,
      currentLocation.latitude, currentLocation.longitude
    ); // Distance in meters

    const timeElapsed = (new Date(currentLocation.created_at) - new Date(previousLocation.created_at)) / 1000; // Time in seconds

    const speed = distance / timeElapsed; // Speed in meters per second

    if (speed > 1) return 'green'; // Adjust these thresholds as needed
    if (speed > 0.5) return 'yellow';
    return 'orange';
  }

  updateTimeDisplay(time) {
    const startTime = new Date(this.recordingStartedAtValue);
    const currentTime = new Date(time);
    this.timeDisplayTarget.textContent = this.formatTime(currentTime - startTime);
  }

  formatTime(milliseconds) {
    let totalSeconds = Math.floor(milliseconds / 1000);
    let hours = Math.floor(totalSeconds / 3600);
    totalSeconds %= 3600;
    let minutes = Math.floor(totalSeconds / 60);
    let seconds = totalSeconds % 60;

    return [hours, minutes, seconds].map(val => val.toString().padStart(2, '0')).join(':');
  }

  sliderValueChanged(event) {
    const time = parseInt(event.target.value, 10);
    this.updateTimeDisplay(time);
    this.drawPaths(time);
  }

  // Ramer-Douglas-Peucker Algorithm
  simplifyPath(points, tolerance) {
    if (points.length < 3) return points;

    let dmax = 0;
    let index = 0;
    const end = points.length - 1;
    for (let i = 1; i < end; i++) {
      const d = this.perpendicularDistance(points[i], points[0], points[end]);
      if (d > dmax) {
        index = i;
        dmax = d;
      }
    }

    if (dmax > tolerance) {
      const recResults1 = this.simplifyPath(points.slice(0, index + 1), tolerance);
      const recResults2 = this.simplifyPath(points.slice(index, end + 1), tolerance);

      return [...recResults1.slice(0, recResults1.length - 1), ...recResults2];
    } else {
      return [points[0], points[end]];
    }
  }

  perpendicularDistance(point, lineStart, lineEnd) {
    const lat1 = this.degreesToRadians(lineStart.latitude);
    const lon1 = this.degreesToRadians(lineStart.longitude);
    const lat2 = this.degreesToRadians(lineEnd.latitude);
    const lon2 = this.degreesToRadians(lineEnd.longitude);
    const lat3 = this.degreesToRadians(point.latitude);
    const lon3 = this.degreesToRadians(point.longitude);

    const distStartToPoint = this.haversineDistance(lat1, lon1, lat3, lon3);
    const distEndPointToPoint = this.haversineDistance(lat2, lon2, lat3, lon3);
    const distStartToEnd = this.haversineDistance(lat1, lon1, lat2, lon2);

    const semiPerimeter = (distStartToPoint + distEndPointToPoint + distStartToEnd) / 2;
    const area = Math.sqrt(semiPerimeter * (semiPerimeter - distStartToPoint) * (semiPerimeter - distEndPointToPoint) * (semiPerimeter - distStartToEnd));

    return (2 * area) / distStartToEnd;
  }

  haversineDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3; // meters
    const φ1 = lat1;
    const φ2 = lat2;
    const Δφ = lat2 - lat1;
    const Δλ = lon2 - lon1;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distance in meters
  }

  degreesToRadians(degrees) {
    return degrees * (Math.PI / 180);
  }
}
