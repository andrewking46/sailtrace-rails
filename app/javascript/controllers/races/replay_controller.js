import { Controller } from "@hotwired/stimulus";
import mapboxgl from "mapbox-gl";

// Constants
const MAPBOX_ACCESS_TOKEN = 'pk.eyJ1IjoiYW5kcmV3a2luZzQ2IiwiYSI6ImNsdGozang0MTBsbDgya21kNGsybGNvODkifQ.-2ds5rFYjTBPgTYc7EG0-A';
const MAPBOX_STYLE = 'mapbox://styles/mapbox/standard';
const PLAYBACK_SPEED = 60000; // One minute of race time per second

// Simple mapping from color names to hex codes
const colorNameToHex = {
  white: '#ffffff',
  black: '#000000',
  red: '#ff0000',
  green: '#00ff00',
  blue: '#0000ff',
  yellow: '#ffff00',
  // Add more colors as needed
};

// Function to convert hex color to rgba with given opacity
function hexToRgba(hex, alpha) {
  const bigint = parseInt(hex.slice(1), 16);
  const r = (bigint >> 16) & 255;
  const g = (bigint >> 8) & 255;
  const b = bigint & 255;
  return `rgba(${r},${g},${b},${alpha})`;
}

// Simple debounce function
function debounce(func, wait) {
  let timeout;
  return function (...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
}

export default class extends Controller {
  static targets = ["slider", "timeDisplay", "map", "playPauseButton"];
  static values = {
    raceId: Number,
    raceStartedAt: Number,
    raceStartLatitude: Number,
    raceStartLongitude: Number
  };

  connect() {
    mapboxgl.accessToken = MAPBOX_ACCESS_TOKEN;
    this.initializeMap();
    this.fetchRaceData();
    this.playing = false; // Track playback state
    this.animationFrameId = null;
    this.lastFrameTime = null; // Last frame time for consistent playback

    document.addEventListener('visibilitychange', this.handleVisibilityChange.bind(this));
  }

  disconnect() {
    document.removeEventListener('visibilitychange', this.handleVisibilityChange.bind(this));
    this.pauseReplay(); // Ensure animation is stopped when controller is disconnected
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.pauseReplay();
    } else if (this.playing) {
      this.startReplay(parseInt(this.sliderTarget.value, 10));
    }
  }

  initializeMap() {
    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: MAPBOX_STYLE,
      center: [this.raceStartLongitudeValue, this.raceStartLatitudeValue],
      zoom: 14
    });

    this.map.on('style.load', this.configureMapStyle.bind(this));
  }

  configureMapStyle() {
    // Hide unnecessary map labels for better performance and clarity
    const properties = ['showRoadLabels', 'showPointOfInterestLabels', 'showTransitLabels'];
    properties.forEach(prop => this.map.setConfigProperty('basemap', prop, false));
  }

  async fetchRaceData() {
    if (!Number.isFinite(this.raceIdValue)) return;

    try {
      const response = await fetch(`/races/${this.raceIdValue}.json`);
      if (!response.ok) throw new Error(`Failed to fetch race data: ${response.statusText}`);

      this.race = await response.json();

      this.initializeBoatSources();
      this.drawPaths(parseInt(this.sliderTarget.value, 10));
      this.centerMap();
    } catch (error) {
      console.error('Error fetching race data:', error);
    }
  }

  initializeBoatSources() {
    this.boatMarkers = {};

    this.race.recordings.forEach(recording => {
      const sourceId = `route-${recording.id}`;

      this.map.addSource(sourceId, {
        type: 'geojson',
        lineMetrics: true,
        data: {
          type: 'Feature',
          properties: {},
          geometry: {
            type: 'LineString',
            coordinates: []
          }
        }
      });

      const hexColor = colorNameToHex[recording.boat.hull_color.toLowerCase()] || '#ffffff';

      this.map.addLayer({
        id: sourceId,
        type: 'line',
        source: sourceId,
        layout: {
          'line-join': 'round',
          'line-cap': 'round'
        },
        paint: {
          'line-gradient': [
            'interpolate',
            ['linear'],
            ['line-progress'],
            0, hexToRgba(hexColor, 0),
            0.5, hexToRgba(hexColor, 1),
            1, hexToRgba(hexColor, 1)
          ],
          'line-width': 2
        }
      });
    });
  }

  drawPaths(time) {
    if (!this.race) return;

    this.race.recordings.forEach(recording => {
      this.updateBoatPath(recording, time);
      this.updateBoatMarker(recording, time);
    });
  }

  updateBoatPath(recording, time) {
    const sourceId = `route-${recording.id}`;
    const pathData = this.getPathData(recording, time);

    if (this.map.getSource(sourceId)) {
      this.map.getSource(sourceId).setData(pathData);
    }
  }

  centerMap() {
    const bounds = new mapboxgl.LngLatBounds();
    this.race.recordings.forEach(recording => {
      recording.recorded_locations.forEach(location => {
        bounds.extend([location.longitude, location.latitude]);
      });
    });

    this.map.fitBounds(bounds, { padding: { top: 20, bottom: 120, left: 20, right: 20 } });
  }

  updateBoatMarker(recording, time) {
    const position = this.getLastPosition(recording, time);
    const recordingId = recording.id;
    const sailNumber = recording.boat.sail_number;
    const color = colorNameToHex[recording.boat.hull_color.toLowerCase()] || '#ffffff';

    if (this.boatMarkers[recordingId]) {
      this.boatMarkers[recordingId].remove();
    }

    if (position) {
      const el = document.createElement('div');
      el.className = 'boat-marker';
      el.style.backgroundColor = color;
      el.style.color = color === '#ffffff' ? 'black' : 'white';
      el.innerText = sailNumber;

      const marker = new mapboxgl.Marker(el)
        .setLngLat([position.adjusted_longitude || position.longitude, position.adjusted_latitude || position.latitude])
        .addTo(this.map);

      this.boatMarkers[recordingId] = marker;
    }
  }

  getPathData(recording, time) {
    const tenMinutesAgo = new Date(time - 10 * 60 * 1000);
    const validLocations = recording.recorded_locations.filter(location =>
      new Date(location.recorded_at) >= tenMinutesAgo && new Date(location.recorded_at) <= time
    );

    return {
      type: 'Feature',
      properties: {},
      geometry: {
        type: 'LineString',
        coordinates: validLocations.map(location => [location.adjusted_longitude || location.longitude, location.adjusted_latitude || location.latitude])
      }
    };
  }

  getLastPosition(recording, time) {
    const tenMinutesAgo = new Date(time - 10 * 60 * 1000);
    const validLocations = recording.recorded_locations.filter(location =>
      new Date(location.recorded_at) >= tenMinutesAgo && new Date(location.recorded_at) <= time
    );

    return validLocations.at(-1) || null;
  }

  updateTimeDisplay(time) {
    const startTime = new Date(this.raceStartedAtValue);
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

    if (this.playing) {
      this.pauseReplay();
      this.startReplay(time);
    }
  }

  sliderValueChangeEnd = debounce((event) => {
    const time = parseInt(event.target.value, 10);
    if (this.playing) {
      this.startReplay(time);
    }
  }, 200); // Adjust the debounce time as needed

  togglePlayPause() {
    if (this.playing) {
      this.pauseReplay();
    } else {
      this.startReplay(parseInt(this.sliderTarget.value, 10));
    }
  }

  startReplay(startTime) {
    this.playing = true;
    this.playPauseButtonTarget.textContent = 'Pause';
    const endTime = parseInt(this.sliderTarget.max, 10);
    let currentTime = startTime;
    const stepTime = PLAYBACK_SPEED;

    const animate = () => {
      if (!this.playing) return;

      const now = Date.now();
      if (this.lastFrameTime) {
        const elapsed = now - this.lastFrameTime;
        currentTime += (elapsed / 1000) * stepTime;
      }
      this.lastFrameTime = now;

      if (currentTime > endTime) {
        currentTime = parseInt(this.sliderTarget.min, 10);
      }
      this.sliderTarget.value = currentTime;
      this.updateTimeDisplay(currentTime);
      this.drawPaths(currentTime);

      this.animationFrameId = requestAnimationFrame(animate);
    };

    this.animationFrameId = requestAnimationFrame(animate);
  }

  pauseReplay() {
    this.playing = false;
    this.playPauseButtonTarget.textContent = 'Play';
    cancelAnimationFrame(this.animationFrameId);
    this.lastFrameTime = null; // Reset the frame time
  }
}
