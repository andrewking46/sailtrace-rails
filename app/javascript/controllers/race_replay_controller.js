import { Controller } from "@hotwired/stimulus";
import mapboxgl from "mapbox-gl";

export default class extends Controller {
  static targets = ["slider", "timeDisplay", "map"];
  static values = {
    userRecordingId: Number,
    raceId: Number,
    raceStartedAt: Number,
    raceEndedAt: Number,
    raceStartLatitude: Number,
    raceStartLongitude: Number
  };

  boatMarkers = {};

  connect() {
    mapboxgl.accessToken = 'pk.eyJ1IjoiYW5kcmV3a2luZzQ2IiwiYSI6ImNsdGozang0MTBsbDgya21kNGsybGNvODkifQ.-2ds5rFYjTBPgTYc7EG0-A'
    this.initializeMap();
    this.fetchRecordingData();
  }

  initializeMap() {
    this.map = new mapboxgl.Map({
      container: this.mapTarget, // container ID
      style: 'mapbox://styles/mapbox/standard', // style URL
      center: [this.raceStartLongitudeValue, this.raceStartLatitudeValue],
      zoom: 13 // starting zoom
    });
  }

  async fetchRecordingData() {
    this.recordings = []

    try {
      if (!Number.isFinite(this.raceIdValue)) return;

      const response = await fetch(`/races/${this.raceIdValue}/recordings.json`);
      const recordings = await response.json();
      this.recordings.push(...recordings);

      // this.simplifyPaths();
      this.initializeBoatSources();
      this.drawPaths(parseInt(this.sliderTarget.value, 10));
      this.centerMap();
    } catch (error) {
      console.error(error);
    }
  }

  initializeBoatSources() {
    this.recordings.forEach(recording => {
      const sourceId = `route-${recording.id}`;

      // Initialize sources for each boat's path with empty data initially
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
          'line-color': recording.boat.hull_color.toLowerCase() || 'white',
          'line-width': 2
        }
      });
    });
  }

  // simplifyPaths() {
  //   this.recordings.forEach(recording => {
  //     const simplifiedPathLocations = this.simplifyPath(recording.recorded_locations, 2);

  //     recording.simplifiedPathLocations = simplifiedPathLocations;
  //   })
  // }

  // Draw paths for the recording(s)
  drawPaths(time) {
    this.recordings.forEach(recording => {
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

  resizeMap() {
    this.map.fitBounds(L.polyline(this.recordings.find((recording) => recording.id = this.userRecordingIdValue).recorded_locations.map(positions => [positions.latitude, positions.longitude])).getBounds());
  }

  centerMap() {
    const bounds = new mapboxgl.LngLatBounds();
    this.recordings.forEach(recording => {
      recording.recorded_locations.forEach(location => {
        bounds.extend([location.longitude, location.latitude]);
      });
    });

    this.map.fitBounds(bounds, { padding: 20 });
  }

  updateBoatMarker(recording, time) {
    const position = this.getLastPosition(recording, time);
    const recordingId = recording.id;
    const sailNumber = recording.boat.sail_number;
    const color = recording.boat.hull_color.toLowerCase() || 'white';

    // Remove the existing marker if there is one
    if (this.boatMarkers[recordingId]) {
      this.boatMarkers[recordingId].remove();
    }

    // If there's a valid position, create a new marker
    if (position) {
      // Create a new marker element
      const el = document.createElement('div');
      el.className = 'boat-marker';
      el.style.backgroundColor = color;
      el.innerText = sailNumber;

      // Create a new marker and add it to the map
      const marker = new mapboxgl.Marker(el)
        .setLngLat([position.longitude, position.latitude])
        .addTo(this.map);

      // Store the new marker in the map with recordingId as the key
      this.boatMarkers[recordingId] = marker;
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
        'coordinates': validLocations.map(location => [location.longitude, location.latitude])
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
    this.centerMap();
  }

  // // Ramer-Douglas-Peucker Algorithm
  // simplifyPath(points, tolerance) {
  //   if (points.length < 3) return points;

  //   let dmax = 0;
  //   let index = 0;
  //   const end = points.length - 1;
  //   for (let i = 1; i < end; i++) {
  //     const d = this.perpendicularDistance(points[i], points[0], points[end]);
  //     if (d > dmax) {
  //       index = i;
  //       dmax = d;
  //     }
  //   }

  //   if (dmax > tolerance) {
  //     const recResults1 = this.simplifyPath(points.slice(0, index + 1), tolerance);
  //     const recResults2 = this.simplifyPath(points.slice(index, end + 1), tolerance);

  //     return [...recResults1.slice(0, recResults1.length - 1), ...recResults2];
  //   } else {
  //     return [points[0], points[end]];
  //   }
  // }

  // perpendicularDistance(point, lineStart, lineEnd) {
  //   const lat1 = this.degreesToRadians(lineStart.latitude);
  //   const lon1 = this.degreesToRadians(lineStart.longitude);
  //   const lat2 = this.degreesToRadians(lineEnd.latitude);
  //   const lon2 = this.degreesToRadians(lineEnd.longitude);
  //   const lat3 = this.degreesToRadians(point.latitude);
  //   const lon3 = this.degreesToRadians(point.longitude);

  //   const distStartToPoint = this.haversineDistance(lat1, lon1, lat3, lon3);
  //   const distEndPointToPoint = this.haversineDistance(lat2, lon2, lat3, lon3);
  //   const distStartToEnd = this.haversineDistance(lat1, lon1, lat2, lon2);

  //   const semiPerimeter = (distStartToPoint + distEndPointToPoint + distStartToEnd) / 2;
  //   const area = Math.sqrt(semiPerimeter * (semiPerimeter - distStartToPoint) * (semiPerimeter - distEndPointToPoint) * (semiPerimeter - distStartToEnd));

  //   return (2 * area) / distStartToEnd;
  // }

  // haversineDistance(lat1, lon1, lat2, lon2) {
  //   const R = 6371e3; // meters
  //   const φ1 = lat1;
  //   const φ2 = lat2;
  //   const Δφ = lat2 - lat1;
  //   const Δλ = lon2 - lon1;

  //   const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
  //             Math.cos(φ1) * Math.cos(φ2) *
  //             Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  //   const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  //   return R * c; // Distance in meters
  // }

  // degreesToRadians(degrees) {
  //   return degrees * (Math.PI / 180);
  // }
}
