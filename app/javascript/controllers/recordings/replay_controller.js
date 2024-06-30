import { Controller } from "@hotwired/stimulus";
import mapboxgl from "mapbox-gl";

export default class extends Controller {
  static targets = ["slider", "timeDisplay", "map"];
  static values = {
    recordingId: Number,
    recordingStartedAt: Number,
    recordingStartLatitude: Number,
    recordingStartLongitude: Number
  };

  connect() {
    mapboxgl.accessToken = 'pk.eyJ1IjoiYW5kcmV3a2luZzQ2IiwiYSI6ImNsdGozang0MTBsbDgya21kNGsybGNvODkifQ.-2ds5rFYjTBPgTYc7EG0-A'
    this.initializeMap();
    this.fetchRecordingData();
  }

  initializeMap() {
    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: 'mapbox://styles/mapbox/standard',
      center: [this.recordingStartLongitudeValue, this.recordingStartLatitudeValue],
      zoom: 14
    });
  }

  async fetchRecordingData() {
    this.recording = {}

    try {
      if (!Number.isFinite(this.recordingIdValue)) return;

      const response = await fetch(`/recordings/${this.recordingIdValue}.json`);
      const recording = await response.json();
      this.recording = recording;

      this.initializeBoatSource();
      this.drawPath(parseInt(this.sliderTarget.value, 10));
      this.centerMap();
    } catch (error) {
      console.error(error);
    }
  }

  initializeBoatSource() {
    const sourceId = `route-${this.recording.id}`;

    // Initialize a source for the boat's path with empty data initially
    this.map.addSource(sourceId, {
      'type': 'geojson',
      'data': {
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'LineString',
          'coordinates': []
        }
      }
    });

    // Add layer for the boat's path
    this.map.addLayer({
      'id': sourceId,
      'type': 'line',
      'source': sourceId,
      'layout': {
        'line-join': 'round',
        'line-cap': 'round'
      },
      'paint': {
        'line-color': this.recording.boat.hull_color.toLowerCase() || 'white',
        'line-width': 2
      }
    });
  }

  // Draw paths for the recording
  drawPath(time) {
    this.updateBoatPath(this.recording, time);
    this.updateBoatMarker(this.recording, time);
  }

  updateBoatPath(recording, time) {
    const sourceId = `route-${recording.id}`;
    const pathData = this.getPathData(recording, time);

    if (this.map.getSource(sourceId)) {
      this.map.getSource(sourceId).setData(pathData);
    }
  }

  resizeMap() {
    this.map.fitBounds(L.polyline(this.recording.recorded_locations.map(positions => [positions.latitude, positions.longitude])).getBounds());
  }

  centerMap() {
    const bounds = new mapboxgl.LngLatBounds();
    this.recording.recorded_locations.forEach(location => {
      bounds.extend([location.longitude, location.latitude]);
    });

    this.map.fitBounds(bounds, { padding: { top: 20, bottom: 120, left: 20, right: 20} });
  }

  updateBoatMarker(recording, time) {
    const position = this.getLastPosition(recording, time);
    const sailNumber = recording.boat.sail_number;
    const color = recording.boat.hull_color.toLowerCase() || 'white';

    // Remove the existing marker if there is one
    if (this.boatMarker) {
      this.boatMarker.remove();
    }

    // If there's a valid position, create a new marker
    if (position) {
      // Create a new marker element
      const el = document.createElement('div');
      el.className = 'boat-marker';
      el.style.backgroundColor = color;
      el.style.color = color == 'white' ? 'black' : 'white';
      el.innerText = sailNumber;

      // Create a new marker and add it to the map
      const marker = new mapboxgl.Marker(el)
        .setLngLat([position.adjusted_longitude || position.longitude, position.adjusted_latitude || position.latitude])
        .addTo(this.map);

      // Store the new marker in the map
      this.boatMarker = marker;
    }
  }

  // Helper method to get the path data for a recording
  getPathData(recording, time) {
    const validLocations = recording.recorded_locations.filter(location =>
      new Date(location.created_at) <= time
    );

    return {
      'type': 'Feature',
      'properties': {},
      'geometry': {
        'type': 'LineString',
        'coordinates': validLocations.map(location => [location.adjusted_longitude || location.longitude, location.adjusted_latitude || location.latitude])
      }
    };
  }

  // Helper method to get the last known position for a recording
  getLastPosition(recording, time) {
    const validLocations = recording.recorded_locations.filter(location =>
      new Date(location.created_at) <= time
    );

    return validLocations.at(-1) || null;
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
    this.drawPath(time);
  }
}

