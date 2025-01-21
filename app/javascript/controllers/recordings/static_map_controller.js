import { Controller } from "@hotwired/stimulus";
import mapboxgl from "mapbox-gl";

/**
 * Recordings::StaticMapController
 *
 * This Stimulus controller displays a static, non-interactive map for a single
 * Recording. It fetches:
 *   1) Recording metadata (start coords, wind direction, etc.).
 *   2) All recorded_locations for that recording (via a cached endpoint).
 *
 * Then it:
 *   - Creates a Mapbox GL map (read-only / no interaction).
 *   - Draws a "halo" line plus a primary route line (in red).
 *   - Places green/red "start"/"end" points.
 *   - Automatically fits the map bounds around the route.
 *
 * Targets:
 *   - (none; the entire element is used as the map container)
 *
 * Values:
 *   - recordingId (Number): The numeric ID of the Recording to show.
 *
 * Lifecycle:
 *   - connect(): Called once when the controller is attached. Loads data then
 *     initializes the map if data is present.
 */
export default class extends Controller {
  static values = {
    recordingId: Number
  };

  /**
   * connect()
   * Called automatically when this controller is placed on the DOM.
   * Loads the required data in sequence, then sets up the map.
   */
  connect() {
    // Public Mapbox token (could be in ENV vars in production).
    mapboxgl.accessToken = "pk.eyJ1IjoiYW5kcmV3a2luZzQ2IiwiYSI6ImNsdGozang0MTBsbDgya21kNGsybGNvODkifQ.-2ds5rFYjTBPgTYc7EG0-A";

    // Decide map style based on user’s system preference (light/dark).
    this.isDarkMode = window.matchMedia?.("(prefers-color-scheme: dark)")?.matches || false;

    // Placeholder for the recording metadata, including recorded_locations.
    this.recording = null;

    // 1) Fetch basic recording metadata
    this.fetchRecordingMetadata()
      .then(() => {
        // 2) Then fetch all recorded locations
        return this.fetchRecordingLocations();
      })
      .then((locations) => {
        if (!locations) {
          // Possibly data isn’t ready or an error occurred; bail out.
          console.warn("No recorded locations to display.");
          return;
        }
        // Attach to our local recording object
        this.recording.recorded_locations = locations;

        // 3) Finally, create the map now that we have all data
        this.createMap();
      })
      .catch((error) => {
        console.error("Error loading recording data:", error);
      });
  }

  /**
   * fetchRecordingMetadata()
   * Loads top-level info for this.recordingIdValue.
   */
  async fetchRecordingMetadata() {
    if (!Number.isFinite(this.recordingIdValue)) return;

    const response = await fetch(`/my/recordings/${this.recordingIdValue}.json`);
    if (!response.ok) {
      throw new Error(`Failed to load recording metadata: ${response.statusText}`);
    }
    this.recording = await response.json();
  }

  /**
   * fetchRecordingLocations()
   * Loads the recording’s location data from /recordings/:id/recorded_locations.json.
   * Returns null if a 202 status indicates the data isn’t yet cached.
   */
  async fetchRecordingLocations() {
    const response = await fetch(`/recordings/${this.recordingIdValue}/recorded_locations.json`);

    if (response.status === 202) {
      // Not yet cached
      console.warn("Recording location data not cached yet. Please try again later.");
      return null;
    }
    if (!response.ok) {
      throw new Error(`Failed to load recording locations: ${response.statusText}`);
    }

    const data = await response.json();
    return data.recorded_locations || [];
  }

  /**
   * createMap()
   * Builds the non-interactive map, sets style, bearing, etc. Then adds the route layer once loaded.
   */
  createMap() {
    // Choose style based on dark mode
    const styleUrl = this.isDarkMode
      ? "mapbox://styles/mapbox/standard"
      : "mapbox://styles/mapbox/standard";

    // Use wind_direction_degrees or fallback to 0
    const initialBearing = this.recording.wind_direction_degrees || 0;

    this.map = new mapboxgl.Map({
      container: this.element, // The <div> our controller is attached to
      style: styleUrl,
      center: [
        this.recording.start_longitude,
        this.recording.start_latitude
      ],
      zoom: 14,
      bearing: initialBearing,
      interactive: false, // static, no user interaction
      fadeDuration: 0
    });

    // Optionally configure style properties
    this.map.on("style.load", () => {
      // If your plan supports these calls, you can hide labels, etc.
      this.map.setConfigProperty?.("basemap", "lightPreset", !this.isDarkMode ? "day" : "dusk");
      this.map.setConfigProperty?.("basemap", "showRoadLabels", false);
      this.map.setConfigProperty?.("basemap", "showTransitLabels", false);
      this.map.setConfigProperty?.("basemap", "showPointOfInterestLabels", false);
      this.map.setConfigProperty?.("basemap", "showPedestrianRoads", false);
    });

    // Once fully loaded, add the route lines + start/end points
    this.map.on("load", () => {
      this.addRouteLayer();
    });
  }

  /**
   * addRouteLayer()
   * Draws a "halo" line plus a primary red route. Also places start/end points, then fits the map.
   */
  addRouteLayer() {
    const locations = this.recording.recorded_locations;
    if (!locations || locations.length === 0) {
      console.warn("No locations available—cannot draw route.");
      return;
    }

    // Convert to array of [lng, lat]
    const coordinates = locations.map((loc) => [
      loc.adjusted_longitude ?? loc.longitude,
      loc.adjusted_latitude  ?? loc.latitude
    ]);

    const startPoint = coordinates[0];
    const endPoint   = coordinates[coordinates.length - 1];

    // Add route as a GeoJSON source
    this.map.addSource("route", {
      type: "geojson",
      data: {
        type: "Feature",
        geometry: {
          type: "LineString",
          coordinates
        }
      }
    });

    // "Halo" line layer beneath the main route
    this.map.addLayer({
      id: "lineBase",
      type: "line",
      source: "route",
      layout: {
        "line-cap": "round",
        "line-join": "round"
      },
      paint: {
        "line-width": 10,
        "line-emissive-strength": 1,
        "line-color": this.isDarkMode ? "#000000" : "#ffffff",
        "line-opacity": 0.2,
        "line-blur": 2
      }
    });

    // Main route line (red)
    this.map.addLayer({
      id: "route",
      type: "line",
      source: "route",
      layout: {
        "line-cap": "round",
        "line-join": "round"
      },
      paint: {
        "line-color": "#ff4403",
        "line-width": 4,
        "line-emissive-strength": 1
      }
    });

    // Add a source for start and end points
    this.map.addSource("path-points", {
      type: "geojson",
      data: {
        type: "FeatureCollection",
        features: [
          {
            type: "Feature",
            geometry: {
              type: "Point",
              coordinates: startPoint
            },
            properties: {
              color: "#00c951", // Green
              description: "Start Point"
            }
          },
          {
            type: "Feature",
            geometry: {
              type: "Point",
              coordinates: endPoint
            },
            properties: {
              color: "#fb2c36", // Red
              description: "End Point"
            }
          }
        ]
      }
    });

    // Draw circles for the start/end
    this.map.addLayer({
      id: "path-points",
      type: "circle",
      source: "path-points",
      paint: {
        "circle-color": ["get", "color"],
        "circle-radius": 8,
        "circle-stroke-width": 3,
        "circle-stroke-color": "#FFFFFF",
        "circle-opacity": 1,
        "circle-emissive-strength": 1,
        "circle-pitch-alignment": "map"
      }
    });

    // Finally, fit the map’s bounds to our route
    const bounds = coordinates.reduce(
      (b, coord) => b.extend(coord),
      new mapboxgl.LngLatBounds(startPoint, startPoint)
    );
    this.map.fitBounds(bounds, {
      padding: 20,
      bearing: this.map.getBearing(),
      pitch: this.map.getPitch()
    });
  }
}
