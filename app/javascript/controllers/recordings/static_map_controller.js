import { Controller } from "@hotwired/stimulus";
import mapboxgl from "mapbox-gl";

export default class extends Controller {
  static values = {
    recordingId: Number,
    replayPath: String,
  };

  connect() {
    mapboxgl.accessToken = 'pk.eyJ1IjoiYW5kcmV3a2luZzQ2IiwiYSI6ImNsdGozang0MTBsbDgya21kNGsybGNvODkifQ.-2ds5rFYjTBPgTYc7EG0-A'
    this.fetchRecordingData();
  }

  async fetchRecordingData() {
    this.recording = {}

    try {
      if (!Number.isFinite(this.recordingIdValue)) return;

      const response = await fetch(`/recordings/${this.recordingIdValue}.json`);
      const recording = await response.json();
      this.recording = recording;

      this.initializeMap();
    } catch (error) {
      console.error(error);
    }
  }

  initializeMap() {
    const map = new mapboxgl.Map({
      container: this.element,
      style: 'mapbox://styles/mapbox/standard', // This can be changed to other map styles
      center: [this.recording.start_longitude, this.recording.start_latitude], // Will be set dynamically
      zoom: 14,
      interactive: false
    });

    map.on('style.load', () => {
      map.setConfigProperty('basemap', 'showRoadLabels', false);
      map.setConfigProperty('basemap', 'showPointOfInterestLabels', false);
      map.setConfigProperty('basemap', 'showTransitLabels', false);
    });

    if (this.recording.recorded_locations.length > 0) {
      this.drawColoredPath(map, this.recording.recorded_locations);
    }
  }

  drawColoredPath(map, locations) {
    if (locations.length > 0) {
      const path = locations.map(loc => [loc.adjusted_longitude || loc.longitude, loc.adjusted_latitude || loc.latitude]);
      map.on('load', () => {
        map.addSource('route', {
          'type': 'geojson',
          'data': {
            'type': 'Feature',
            'properties': {},
            'geometry': {
              'type': 'LineString',
              'coordinates': path
            }
          }
        });
        map.addLayer({
          'id': 'route',
          'type': 'line',
          'source': 'route',
          'layout': {
            'line-join': 'round',
            'line-cap': 'round'
          },
          'paint': {
            'line-color': this.recording.boat.hull_color.toLowerCase() || 'white',
            'line-width': 3
          }
        });
        const bounds = path.reduce(function(bounds, coord) {
          return bounds.extend(coord);
        }, new mapboxgl.LngLatBounds(path[0], path[0]));

        map.fitBounds(bounds, {
          padding: 20
        });
      });
    }
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
    // Convert points to radians
    const lat1 = this.degreesToRadians(lineStart.adjusted_latitude || lineStart.latitude);
    const lon1 = this.degreesToRadians(lineStart.adjusted_longitude || lineStart.longitude);
    const lat2 = this.degreesToRadians(lineEnd.adjusted_latitude || lineEnd.latitude);
    const lon2 = this.degreesToRadians(lineEnd.adjusted_longitude || lineEnd.longitude);
    const lat3 = this.degreesToRadians(point.adjusted_latitude || point.latitude);
    const lon3 = this.degreesToRadians(point.adjusted_longitude || point.longitude);

    // Calculate the distances from point to line start/end
    const distStartToPoint = this.haversineDistance(lat1, lon1, lat3, lon3);
    const distEndPointToPoint = this.haversineDistance(lat2, lon2, lat3, lon3);

    // Calculate the distance from line start to end
    const distStartToEnd = this.haversineDistance(lat1, lon1, lat2, lon2);

    // Calculate the area of the triangle formed by the three points
    const semiPerimeter = (distStartToPoint + distEndPointToPoint + distStartToEnd) / 2;
    const area = Math.sqrt(semiPerimeter * (semiPerimeter - distStartToPoint) * (semiPerimeter - distEndPointToPoint) * (semiPerimeter - distStartToEnd));

    // Calculate the distance from the point to the line (perpendicular)
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

  getSegmentColor(prevLocation, location) {
    const speed = this.calculateSpeed(prevLocation, location);

    if (speed > 1.5) return 'green';
    if (speed > 1.25) return 'limegreen';
    if (speed > 1) return 'yellowgreen';
    if (speed > 0.75) return 'yellow';
    if (speed > 0.5) return 'gold';
    if (speed > 0.25) return 'orange';
    return 'red';
  }

  calculateSpeed(prevLocation, location) {
    const distance = this.calculateDistance(
      prevLocation.adjusted_latitude || prevLocation.latitude, prevLocation.adjusted_longitude || prevLocation.longitude,
      location.adjusted_latitude || location.latitude, location.adjusted_longitude || location.longitude
    );
    const timeElapsed = (new Date(location.recorded_at) - new Date(prevLocation.recorded_at)) / 1000;

    return distance / timeElapsed;
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

    return R * c;
  }

  goToReplay(event) {
    event.preventDefault();
    window.location.href = this.replayPathValue;
  }
}
