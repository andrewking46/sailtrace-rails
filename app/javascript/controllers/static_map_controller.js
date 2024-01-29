import { Controller } from "@hotwired/stimulus";
import L from "leaflet";

export default class extends Controller {
  static values = {
    recordingId: Number,
    boatColor: String,
    replayPath: String
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
    const simplifiedLocations = this.simplifyPath(locations, 4);

    for (let i = 1; i < simplifiedLocations.length; i++) {
      const prevLocation = simplifiedLocations[i - 1];
      const location = simplifiedLocations[i];
      const color = this.getSegmentColor(prevLocation, location);

      L.polyline([
        [prevLocation.latitude, prevLocation.longitude],
        [location.latitude, location.longitude]
      ], { color, weight: 3 }).addTo(map);
    }

    if (simplifiedLocations.length > 0) {
      map.fitBounds(L.polyline(simplifiedLocations.map(loc => [loc.latitude, loc.longitude])).getBounds());
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
    const lat1 = this.degreesToRadians(lineStart.latitude);
    const lon1 = this.degreesToRadians(lineStart.longitude);
    const lat2 = this.degreesToRadians(lineEnd.latitude);
    const lon2 = this.degreesToRadians(lineEnd.longitude);
    const lat3 = this.degreesToRadians(point.latitude);
    const lon3 = this.degreesToRadians(point.longitude);

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
      prevLocation.latitude, prevLocation.longitude,
      location.latitude, location.longitude
    );
    const timeElapsed = (new Date(location.created_at) - new Date(prevLocation.created_at)) / 1000;

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
