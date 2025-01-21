import { Controller } from "@hotwired/stimulus";
import mapboxgl from "mapbox-gl";

/**
 * RecordingSpeedMapController
 *
 * This Stimulus controller manages the "Speed Map" view for a single Recording.
 * It fetches the Recording + location data from the server, creates a Mapbox GL
 * map, draws a color-coded track showing boat speed, and provides a slider to
 * scrub through time, moving a "boat" marker accordingly. It also supports an
 * optional "Follow Mode" where the camera automatically follows the boat.
 *
 * Targets:
 * - loadingOverlay: The initial "Loading..." overlay displayed until data and map are ready
 * - mapContainer: The wrapper around the actual map (hidden until data is ready)
 * - map: The <div> where Mapbox GL draws its map
 * - slider: The range input slider allowing scrubbing through the recording's timeline
 * - timeDisplay: A small textual display showing the elapsed time (HH:MM:SS) from the start
 * - followModeButton: Toggle for enabling/disabling "Follow Mode" camera locking
 *
 * Values:
 * - recordingId: The ID of the Recording resource
 * - windDirection: Optional (degrees) used as an initial bearing for the map
 *
 * Lifecycle:
 * - connect(): Called once when placed on the page; triggers data fetch & map setup
 * - disconnect(): Called automatically by Stimulus when this controller is removed
 */
export default class extends Controller {
  static values = {
    recordingId: Number,
    windDirection: Number
  };

  static targets = [
    "loadingOverlay",
    "mapContainer",
    "map",
    "slider",
    "timeDisplay",
    "followModeButton"
  ];

  /**
   * connect()
   * Called once when the controller is attached to the DOM.
   * Initializes variables and begins fetching data to build the map.
   */
  connect() {
    // Store your public Mapbox token here (typically you might set this in an ENV var).
    this.mapboxToken = "pk.eyJ1IjoiYW5kcmV3a2luZzQ2IiwiYSI6ImNsdGozang0MTBsbDgya21kNGsybGNvODkifQ.-2ds5rFYjTBPgTYc7EG0-A";

    // Core data placeholders
    this.recording = null;
    this.locations = [];

    // Speed outlier range
    this.minSpeed = 0;
    this.maxSpeed = 0;

    // Map / UI states
    this.followMode = false;     // Whether camera stays locked on boat
    this.currentTime = 0;        // Current timeline time (ms since epoch)
    this.startTimestamp = 0;     // Earliest recorded location time
    this.endTimestamp = 0;       // Latest recorded location time

    // Marker references
    this.boatMarker = null;
    this.boatPopup = null;

    // Decide map style based on user’s system preference (light/dark)
    this.isDarkMode = (
      window.matchMedia?.("(prefers-color-scheme: dark)")?.matches || false
    );

    // Immediately fetch data; once loaded, we'll initialize the map
    this.fetchData();
  }

  /**
   * disconnect()
   * Called automatically by Stimulus when the user navigates away or
   * this controller is removed. Cleans up any Mapbox resources.
   */
  disconnect() {
    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }

  /**
   * fetchData()
   * Fetches the Recording metadata JSON, then the associated recorded_locations.
   * Once the data arrives, we prepare speed info and set up the map.
   */
  async fetchData() {
    try {
      // 1. Fetch minimal metadata
      const metaRes = await fetch(`/my/recordings/${this.recordingIdValue}.json`);
      if (!metaRes.ok) throw new Error("Could not load recording metadata");
      this.recording = await metaRes.json();

      // 2. Fetch location data
      const locRes = await fetch(`/recordings/${this.recordingIdValue}/recorded_locations.json`);
      if (locRes.status === 202) {
        // Data not ready / still processing
        console.warn("Recording locations not yet cached. You may wish to handle this gracefully.");
        return;
      }
      if (!locRes.ok) throw new Error("Could not load recorded locations");

      const data = await locRes.json();
      this.locations = data.recorded_locations || [];

      // Check that we have enough points to do something useful
      if (this.locations.length < 2) {
        console.warn("Not enough location data to draw a path.");
      }

      // Prepare min / max speed ignoring top/bottom outliers
      this.prepareSpeedOutlierRange();

      // Convert recorded_at timestamps to numeric time for easy slider usage
      const times = this.locations
        .filter((loc) => loc.recorded_at)
        .map((loc) => new Date(loc.recorded_at).getTime());

      if (times.length > 0) {
        this.startTimestamp = Math.min(...times);
        this.endTimestamp   = Math.max(...times);
        this.sliderTarget.min   = this.startTimestamp;
        this.sliderTarget.max   = this.endTimestamp;
        this.sliderTarget.value = this.startTimestamp;
        this.currentTime        = this.startTimestamp;
      } else {
        console.warn("No valid timestamps in location data.");
      }

      // At this point, we have all data needed for the map.
      this.createMap();

      // Hide the loading overlay, show the map container
      this.loadingOverlayTarget.classList.add("hidden");
      this.mapContainerTarget.classList.remove("hidden");
    } catch (err) {
      console.error("Error fetching data:", err);
    }
  }

  /**
   * prepareSpeedOutlierRange()
   * Derives a "usable" min & max speed by ignoring the top/bottom 5% of speeds.
   * This helps the color gradient not get skewed by outliers.
   */
  prepareSpeedOutlierRange() {
    const speeds = this.locations
      .map((l) => parseFloat(l.velocity) || 0)
      .filter((v) => v > 0)
      .sort((a, b) => a - b);

    if (speeds.length < 2) {
      // Fallback if we have 0 or 1 valid speeds
      this.minSpeed = 0;
      this.maxSpeed = 1;
      return;
    }

    const fivePctIndex       = Math.floor(speeds.length * 0.05);
    const ninetyFivePctIndex = Math.ceil(speeds.length * 0.95) - 1;

    this.minSpeed = speeds[fivePctIndex] || 0;
    this.maxSpeed = speeds[ninetyFivePctIndex] || (this.minSpeed + 1);

    // Ensure we have at least a small valid range
    if (this.minSpeed >= this.maxSpeed) {
      this.minSpeed = Math.max(0, this.minSpeed - 1);
      this.maxSpeed += 1;
    }
  }

  /**
   * createMap()
   * Creates and configures the Mapbox GL map, then draws all layers / markers.
   */
  createMap() {
    mapboxgl.accessToken = this.mapboxToken;

    // Determine an appropriate style for dark/light mode
    const styleUrl = this.isDarkMode
      ? "mapbox://styles/mapbox/standard"
      : "mapbox://styles/mapbox/standard";

    // Start the map with an initial bearing from wind direction if provided
    const initialBearing = this.windDirectionValue || 0;

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: styleUrl,      // <== Use the style we computed
      center: [
        this.recording.start_longitude,
        this.recording.start_latitude
      ],
      zoom: 14,
      bearing: initialBearing,
      interactive: true,
      fadeDuration: 0 // Faster initial rendering (no fade)
    });

    // Add navigation controls (zoom/rotate)
    this.map.addControl(new mapboxgl.NavigationControl(), "top-left");

    // Once the style is loaded, configure map properties and draw layers
    this.map.on("style.load", () => {
      // These may be custom properties if using Mapbox v2 style components
      // If these calls are invalid for your plan/SDK version, remove them.
      this.map.setConfigProperty?.("basemap", "lightPreset", !this.isDarkMode ? "day" : "dusk");
      this.map.setConfigProperty?.("basemap", "showRoadLabels", false);
      this.map.setConfigProperty?.("basemap", "showTransitLabels", false);
      this.map.setConfigProperty?.("basemap", "showPointOfInterestLabels", false);
      this.map.setConfigProperty?.("basemap", "showPedestrianRoads", false);
    });

    // The 'load' event fires once the style and map are fully ready
    this.map.on("load", () => {
      this.drawColorPath();
      this.placeStartEndDots();
      this.fitBoundsWithPadding();
      this.createBoatMarker();
      this.updateTimeDisplay(this.startTimestamp);
    });
  }

  /**
   * drawColorPath()
   * Draws a multi-colored line representing boat speed using a gradient from
   * minSpeed to maxSpeed. Lower speeds appear more red, higher speeds more green.
   */
  drawColorPath() {
    if (!this.map || this.locations.length < 2) return;

    // Build array of [lng, lat] for each location
    const coordinates = this.locations.map((loc) => [
      loc.adjusted_longitude ?? loc.longitude,
      loc.adjusted_latitude  ?? loc.latitude
    ]);

    // Speeds array, aligned with the location array
    const speeds = this.locations.map((loc) => parseFloat(loc.velocity) || 0);

    // line-progress gradient steps (one color for each point)
    const gradientStops = [];
    for (let i = 0; i < speeds.length; i++) {
      const fraction = i / (speeds.length - 1);
      const color = this.speedToColor(speeds[i]);
      gradientStops.push(fraction, color);
    }

    // Add a GeoJSON source for the track
    this.map.addSource("speedLine", {
      type: "geojson",
      data: {
        type: "Feature",
        geometry: {
          type: "LineString",
          coordinates
        }
      },
      lineMetrics: true, // required for line-progress
      tolerance: 0.5
    });

    // Baseline "halo" line layer
    this.map.addLayer({
      id: "speedLineBase",
      type: "line",
      source: "speedLine",
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

    // Actual color gradient line on top
    this.map.addLayer({
      id: "speedLine",
      type: "line",
      source: "speedLine",
      layout: {
        "line-cap": "round",
        "line-join": "round"
      },
      paint: {
        "line-width": 4,
        "line-emissive-strength": 1,
        "line-gradient": [
          "interpolate",
          ["linear"],
          ["line-progress"],
          ...gradientStops
        ]
      }
    });
  }

  /**
   * speedToColor(speed)
   * Given a speed value, returns an 'rgb(r, g, b)' string for the color
   * gradient from red (minSpeed) to green (maxSpeed).
   */
  speedToColor(speed) {
    // Normalize speed to a 0..1 fraction within [this.minSpeed..this.maxSpeed]
    const clamped = Math.max(this.minSpeed, Math.min(speed, this.maxSpeed));
    const fraction = (clamped - this.minSpeed) / (this.maxSpeed - this.minSpeed || 1);

    // Basic red -> green interpolation
    const r = Math.round(255 + (0 - 255) * fraction);
    const g = Math.round(0 + (255 - 0) * fraction);
    const b = 0;

    return `rgb(${r},${g},${b})`;
  }

  /**
   * placeStartEndDots()
   * Draws small circle markers for the first and last location in the path.
   */
  placeStartEndDots() {
    if (!this.map || this.locations.length < 1) return;

    // Start point
    const firstLoc = this.locations[0];
    this.map.addSource("startPoint", {
      type: "geojson",
      data: {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [
            firstLoc.adjusted_longitude ?? firstLoc.longitude,
            firstLoc.adjusted_latitude  ?? firstLoc.latitude
          ]
        }
      }
    });
    this.map.addLayer({
      id: "startPoint",
      type: "circle",
      source: "startPoint",
      paint: {
        "circle-radius": 8,
        "circle-color": "#00c951",
        "circle-stroke-width": 3,
        "circle-stroke-color": "#ffffff",
        "circle-emissive-strength": 1,
        "circle-pitch-alignment": "map"
      }
    });

    // End point
    const lastLoc = this.locations[this.locations.length - 1];
    this.map.addSource("endPoint", {
      type: "geojson",
      data: {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [
            lastLoc.adjusted_longitude ?? lastLoc.longitude,
            lastLoc.adjusted_latitude  ?? lastLoc.latitude
          ]
        }
      }
    });
    this.map.addLayer({
      id: "endPoint",
      type: "circle",
      source: "endPoint",
      paint: {
        "circle-radius": 8,
        "circle-color": "#fb2c36",
        "circle-stroke-width": 3,
        "circle-stroke-color": "#ffffff",
        "circle-emissive-strength": 1,
        "circle-pitch-alignment": "map"
      }
    });
  }

  /**
   * fitBoundsWithPadding()
   * Fits the map to the bounding box of all location points with nice padding.
   */
  fitBoundsWithPadding() {
    if (!this.map || this.locations.length < 1) return;

    const bounds = new mapboxgl.LngLatBounds();
    this.locations.forEach((loc) => {
      bounds.extend([
        loc.adjusted_longitude ?? loc.longitude,
        loc.adjusted_latitude  ?? loc.latitude
      ]);
    });

    this.map.fitBounds(bounds, {
      padding: {
        top: 20,
        right: 20,
        bottom: 100,
        left: 20
      },
      bearing: this.map.getBearing(),
      maxZoom: 17,
      pitch: this.map.getPitch()
    });
  }

  /**
   * createBoatMarker()
   * Creates a custom marker for the boat (circle with sail number),
   * along with a popup to display current speed (updated in real-time).
   */
  createBoatMarker() {
    if (!this.map || !this.recording || this.locations.length < 1) return;

    // Attempt to derive hull color (fallback to white)
    const rawHullColor = (this.recording.boat?.hull_color || "white").toLowerCase();
    const hullColorCss = this.resolveCssColor(rawHullColor);

    // Text color is black for a white hull, otherwise white
    const textColor = (rawHullColor === "white") ? "#000000" : "#ffffff";
    const sailNumber = this.recording.boat?.sail_number || "???";

    // Marker element
    const markerEl = document.createElement("div");
    markerEl.style.width           = "2rem";
    markerEl.style.height          = "2rem";
    markerEl.style.borderRadius    = "50%";
    markerEl.style.border          = "2px solid #ffffff";
    markerEl.style.display         = "flex";
    markerEl.style.alignItems      = "center";
    markerEl.style.justifyContent  = "center";
    markerEl.style.backgroundColor = hullColorCss;
    markerEl.style.color           = textColor;
    markerEl.style.fontSize        = "12px";
    markerEl.style.fontWeight      = "bold";
    markerEl.textContent           = sailNumber;

    // Popup to show speed
    this.boatPopup = new mapboxgl.Popup({
      offset: 25,
      closeButton: false,
      closeOnClick: false,
      className: "dark:text-gray-900"
    });

    // Create Marker + attach popup
    const firstLoc = this.locations[0];
    this.boatMarker = new mapboxgl.Marker({ element: markerEl, pitchAlignment: "map" })
      .setLngLat([
        firstLoc.adjusted_longitude ?? firstLoc.longitude,
        firstLoc.adjusted_latitude  ?? firstLoc.latitude
      ])
      .setPopup(this.boatPopup)
      .addTo(this.map);

    // Show the popup initially
    this.boatMarker.togglePopup();
  }

  /**
   * resolveCssColor(hullColorName)
   * Given a hull color name (e.g. "white", "red"), returns a valid CSS color.
   * Unknown names fallback to "#ffffff".
   */
  resolveCssColor(hullColorName) {
    const knownColors = [
      "white", "black", "red", "blue", "green", "yellow",
      "orange", "gray", "purple", "pink", "brown", "silver"
    ];
    return knownColors.includes(hullColorName)
      ? hullColorName
      : "#ffffff";
  }

  /**
   * onSliderInput(event)
   * Fired whenever the user scrubs the slider. We update the internal `currentTime`
   * and move the boat marker to the nearest location for that time.
   */
  onSliderInput(event) {
    const newTime = parseInt(event.currentTarget.value, 10);
    this.currentTime = newTime;
    this.updateTimeDisplay(newTime);
    this.updateBoatMarkerPosition(newTime);
    this.maybeUpdateFollowModeCamera(newTime);
  }

  /**
   * updateBoatMarkerPosition(timeMs)
   * Moves the boat marker and updates the popup speed text based on the location
   * nearest to the given `timeMs`.
   */
  updateBoatMarkerPosition(timeMs) {
    if (!this.boatMarker) return;

    const loc = this.findNearestLocation(timeMs);
    if (!loc) return;

    this.boatMarker.setLngLat([
      loc.adjusted_longitude ?? loc.longitude,
      loc.adjusted_latitude  ?? loc.latitude
    ]);

    const speed = parseFloat(loc.velocity) || 0;
    if (this.boatPopup) {
      this.boatPopup.setText(`${speed.toFixed(1)} kts`);
    }
  }

  /**
   * findNearestLocation(timeMs)
   * Returns the location from `this.locations` whose recorded_at is
   * closest to `timeMs`.
   */
  findNearestLocation(timeMs) {
    if (this.locations.length < 1) return null;

    let best = null;
    let bestDiff = Infinity;

    for (const loc of this.locations) {
      const t = new Date(loc.recorded_at).getTime();
      const diff = Math.abs(t - timeMs);
      if (diff < bestDiff) {
        bestDiff = diff;
        best = loc;
      }
    }
    return best;
  }

  /**
   * updateTimeDisplay(timeMs)
   * Updates the text-based timeline display (HH:MM:SS) based on
   * how far timeMs is from this.startTimestamp.
   */
  updateTimeDisplay(timeMs) {
    const delta = timeMs - this.startTimestamp;
    if (delta < 0) {
      this.timeDisplayTarget.textContent = "00:00:00";
      return;
    }

    const totalSec = Math.floor(delta / 1000);
    const hh = String(Math.floor(totalSec / 3600)).padStart(2, "0");
    const mm = String(Math.floor((totalSec % 3600) / 60)).padStart(2, "0");
    const ss = String(totalSec % 60).padStart(2, "0");

    this.timeDisplayTarget.textContent = `${hh}:${mm}:${ss}`;
  }

  /**
   * toggleFollowMode()
   * Toggles the camera "follow mode" on/off. Disables user panning/zooming
   * when active, and keeps the camera trained on the boat location.
   */
  toggleFollowMode() {
    this.followMode = !this.followMode;

    if (this.followMode) {
      // Update button text
      this.followModeButtonTarget.textContent = "Stop Follow Mode";

      // Disable user interactions in follow mode
      this.map.dragPan.disable();
      this.map.scrollZoom.disable();
      this.map.boxZoom.disable();
      this.map.keyboard.disable();
      this.map.doubleClickZoom.disable();
      this.map.touchZoomRotate.disable();

      // Slight tilt for a more dynamic view
      this.map.setPitch(60);

      // Immediately recenter on the boat
      this.maybeUpdateFollowModeCamera(this.currentTime);
    } else {
      // Update button text
      this.followModeButtonTarget.textContent = "Enable Follow Mode";

      // Re-enable user interactions
      this.map.dragPan.enable();
      this.map.scrollZoom.enable();
      this.map.boxZoom.enable();
      this.map.keyboard.enable();
      this.map.doubleClickZoom.enable();
      this.map.touchZoomRotate.enable();

      // Reset pitch or choose a default
      this.map.easeTo({
        duration: 200,
        pitch: 0
      });
    }
  }

  /**
   * maybeUpdateFollowModeCamera(timeMs)
   * If followMode is active, smoothly moves the camera to the boat's position
   * at the given timeMs, preserving the current bearing and pitch.
   */
  maybeUpdateFollowModeCamera(timeMs) {
    if (!this.followMode) return;

    const loc = this.findNearestLocation(timeMs);
    if (!loc) return;

    this.map.easeTo({
      center: [
        loc.adjusted_longitude ?? loc.longitude,
        loc.adjusted_latitude  ?? loc.latitude
      ],
      duration: 100,
      bearing: this.map.getBearing(),
      pitch: this.map.getPitch()
    });
  }
}
