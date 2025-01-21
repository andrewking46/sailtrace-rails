import { Controller } from "@hotwired/stimulus";
import mapboxgl from "mapbox-gl";

/**
 * Races::ReplayController
 *
 * This controller handles the "replay" view for a Race, showing:
 * - A Mapbox GL map with each boat’s track
 * - A timeline slider to move through time
 * - A play/pause button to animate boat movements across the race
 * - Per-boat speed and heading displays, updated as time changes
 *
 * Targets:
 *   - loadingOverlay: The "Loading..." overlay we hide once data is ready
 *   - mapContainer: The parent container for the map (initially hidden)
 *   - map: The <div> where Mapbox GL will draw
 *   - slider: A range input (min..max = start..end times) for manual scrubbing
 *   - timeDisplay: The textual display of HH:MM:SS from race start
 *   - playPauseButton: The button that toggles playback on/off
 *   - infoPanel: A container for top-right info if needed
 *   - boatStatsContainer: The pre-rendered set of boat rows, each with speed/heading "cells"
 *
 * Values:
 *   - raceId: The numeric ID of the Race resource
 *
 * Lifecycle:
 *   - connect(): Called once when attached. Fetches data and prepares map + replay.
 *   - disconnect(): Called automatically when the controller is removed; cleans up.
 */
export default class extends Controller {
  static values = {
    raceId: Number
  };

  static targets = [
    "loadingOverlay",
    "mapContainer",
    "map",
    "slider",
    "timeDisplay",
    "playPauseButton",
    "infoPanel",
    "boatStatsContainer"
  ];

  /**
   * connect()
   * Initializes state, fetches race/recording data, and eventually creates the map.
   */
  connect() {
    // Mapbox public token (could be stored in environment variables in production).
    this.mapboxToken = "pk.eyJ1IjoiYW5kcmV3a2luZzQ2IiwiYSI6ImNsdGozang0MTBsbDgya21kNGsybGNvODkifQ.-2ds5rFYjTBPgTYc7EG0-A";

    // Core map/race data
    this.map = null;
    this.race = null;
    this.recordings = []; // Array of recording objects, each with boat info + recorded_locations

    // Playback-related state
    this.boatMarkers = {};    // { recordingId: mapboxgl.Marker }
    this.playing = false;
    this.animationFrameId = null;
    this.lastFrameTime = 0;

    // Time boundaries
    this.currentTime = 0;
    this.startTimestamp = 0;
    this.endTimestamp = 0;

    // Playback speed: e.g. 1 minute of real time per second of animation
    this.PLAYBACK_SPEED = 60000;
    // Limit frame updates to 30fps
    this.maxFPS = 30;

    // Light/dark styling
    this.isDarkMode = (
      window.matchMedia?.("(prefers-color-scheme: dark)")?.matches || false
    );

    // Container for speed/heading <span> references
    this.boatStatElements = {};

    // Collect references to each boat's speed/heading elements in the DOM
    this.collectBoatStatElements();

    // Fetch the race data + recordings
    this.fetchRaceData();
  }

  /**
   * disconnect()
   * Automatically called when the controller is removed. Cleanup map + animations.
   */
  disconnect() {
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }
    if (this.map) {
      this.map.remove();
      this.map = null;
    }
  }

  /**
   * collectBoatStatElements()
   * Pre-scans the boatStatsContainerTarget to find each row’s speed + heading spans.
   */
  collectBoatStatElements() {
    const container = this.boatStatsContainerTarget;

    // Each child row has data-boat-id="<rec.id>", so we find them:
    container.querySelectorAll("[data-boat-id]").forEach((rowEl) => {
      const recId = rowEl.getAttribute("data-boat-id");
      if (!recId) return;

      const speedSpan   = rowEl.querySelector(`[data-speed-target='${recId}']`);
      const headingSpan = rowEl.querySelector(`[data-heading-target='${recId}']`);

      this.boatStatElements[recId] = {
        speedSpan,
        headingSpan
      };
    });
  }

  /**
   * fetchRaceData()
   * Fetches the core Race JSON, then each recording’s location data.
   * Once complete, we set up the map and initial UI.
   */
  async fetchRaceData() {
    try {
      // 1) Load the race
      const res = await fetch(`/races/${this.raceIdValue}.json`);
      if (!res.ok) throw new Error("Could not load race data");
      this.race = await res.json();

      // 2) Compute an initial bearing from any known wind directions
      const windDirs = [];
      this.race.recordings.forEach((r) => {
        if (r.wind_direction_degrees && r.wind_direction_degrees !== 0) {
          windDirs.push(r.wind_direction_degrees);
        }
      });
      this.initialBearing = windDirs.length
        ? windDirs.reduce((sum, deg) => sum + deg, 0) / windDirs.length
        : 0;

      // 3) Fetch location data for each recording (in parallel)
      await Promise.all(
        this.race.recordings.map(async (rec) => {
          const locUrl = `/recordings/${rec.id}/recorded_locations.json`;
          const locRes = await fetch(locUrl);

          if (locRes.status === 202) {
            // Not yet processed
            console.warn(`Recording ${rec.id} data not ready yet.`);
            rec.recorded_locations = [];
            return;
          }
          if (!locRes.ok) {
            console.warn(`Failed to fetch locations for recording ${rec.id}`);
            rec.recorded_locations = [];
            return;
          }
          const data = await locRes.json();
          rec.recorded_locations = data.recorded_locations || [];
        })
      );
      this.recordings = this.race.recordings;

      // 4) Determine earliest and latest timestamps across all recordings
      this.computeGlobalStartEnd();

      // 5) Create the map now that we have data
      this.createMap();

      // 6) Hide the loading overlay, show the map container
      this.loadingOverlayTarget.classList.add("hidden");
      this.mapContainerTarget.classList.remove("hidden");

      // 7) Initialize slider range
      if (this.startTimestamp < this.endTimestamp) {
        this.sliderTarget.min   = this.startTimestamp;
        this.sliderTarget.max   = this.endTimestamp;
        this.sliderTarget.value = this.startTimestamp;
        this.currentTime        = this.startTimestamp;
      }

      // 8) Update the UI for time=0 (start)
      this.updateTimeDisplay(this.startTimestamp);
      this.updateBoatPositions(this.startTimestamp);
      this.updateBoatTrails(this.startTimestamp);
      this.updateBoatStatsUI(this.startTimestamp);

    } catch (err) {
      console.error("fetchRaceData error:", err);
    }
  }

  /**
   * computeGlobalStartEnd()
   * Iterates over all boat recordings to find the earliest and latest timestamps.
   */
  computeGlobalStartEnd() {
    let minT = Infinity;
    let maxT = -Infinity;

    this.race.recordings.forEach((rec) => {
      const locs = rec.recorded_locations || [];
      locs.forEach((loc) => {
        const t = new Date(loc.recorded_at).getTime();
        if (t < minT) minT = t;
        if (t > maxT) maxT = t;
      });
    });

    if (!isFinite(minT)) {
      // Edge case: no valid times at all
      minT = 0;
      maxT = 0;
    }
    this.startTimestamp = minT;
    this.endTimestamp   = maxT;
    this.currentTime    = minT;
  }

  /**
   * createMap()
   * Creates the Mapbox GL map, sets its style, and once loaded,
   * adds markers and path sources for each boat, then fits the bounds.
   */
  createMap() {
    mapboxgl.accessToken = this.mapboxToken;

    // Choose a style based on dark/light mode
    const styleUrl = this.isDarkMode
      ? "mapbox://styles/mapbox/standard"
      : "mapbox://styles/mapbox/standard";

    this.map = new mapboxgl.Map({
      container: this.mapTarget,
      style: styleUrl,
      center: [this.race.start_longitude, this.race.start_latitude],
      zoom: 14,
      bearing: this.initialBearing,
      interactive: true,
      fadeDuration: 0
    });

    // Add zoom/rotate control
    this.map.addControl(new mapboxgl.NavigationControl(), "top-left");

    // Configure map style once loaded
    this.map.on("style.load", () => {
      // Turn off some default labels if relevant to your plan/SDK
      this.map.setConfigProperty?.("basemap", "lightPreset", !this.isDarkMode ? "day" : "dusk");
      this.map.setConfigProperty?.("basemap", "showRoadLabels", false);
      this.map.setConfigProperty?.("basemap", "showTransitLabels", false);
      this.map.setConfigProperty?.("basemap", "showPointOfInterestLabels", false);
      this.map.setConfigProperty?.("basemap", "showPedestrianRoads", false);
    });

    // Once fully loaded, add boat markers & path layers, then fit bounds
    this.map.on("load", () => {
      this.recordings.forEach((rec) => {
        // Skip if no data
        if (!rec.recorded_locations || rec.recorded_locations.length === 0) {
          console.warn(`Skipping recording ${rec.id} (no data)`);
          return;
        }
        // Create a marker for each boat
        this.addBoatMarker(rec);
        // Add a "trail" GeoJSON source + layers for the boat’s recent path
        this.addBoatPathSource(rec);
      });
      // Finally, fit map bounds around all boats
      this.fitBoundsWithPadding();
    });
  }

  /**
   * addBoatMarker(rec)
   * Creates a color-coded marker for the boat with its sail number at the first location.
   */
  addBoatMarker(rec) {
    const sailNumber = rec.boat?.sail_number || "???";
    const rawColor   = (rec.boat?.hull_color || "white").toLowerCase();
    const cssColor   = this.resolveCssColor(rawColor);
    const textColor  = (rawColor === "white") ? "#000" : "#fff";

    const el = document.createElement("div");
    el.className = "flex items-center justify-center rounded-full border-2 border-white text-xs font-bold";
    el.style.width           = "2rem";
    el.style.height          = "2rem";
    el.style.backgroundColor = cssColor;
    el.style.color           = textColor;
    el.textContent           = sailNumber;

    let initialCoord = [9999, 9999]; // Fallback coords
    if (rec.recorded_locations.length > 0) {
      const firstLoc = rec.recorded_locations[0];
      initialCoord = [
        firstLoc.adjusted_longitude ?? firstLoc.longitude,
        firstLoc.adjusted_latitude  ?? firstLoc.latitude
      ];
    }

    const marker = new mapboxgl.Marker({
      element: el,
      pitchAlignment: "map"
    })
      .setLngLat(initialCoord)
      .addTo(this.map);

    this.boatMarkers[rec.id] = marker;
  }

  /**
   * addBoatPathSource(rec)
   * Sets up a GeoJSON source + two line layers (a glow + a main line)
   * that show a short trailing path behind the boat.
   */
  addBoatPathSource(rec) {
    const sourceId = `boat-trail-${rec.id}`;
    this.map.addSource(sourceId, {
      type: "geojson",
      lineMetrics: true, // required for line-progress gradient
      tolerance: 0.5,
      data: {
        type: "Feature",
        geometry: { type: "LineString", coordinates: [] }
      }
    });

    // Glow / halo layer
    this.map.addLayer({
      id: `${sourceId}-glow`,
      type: "line",
      source: sourceId,
      layout: {
        "line-join": "round",
        "line-cap": "round"
      },
      paint: {
        "line-color": this.resolveCssColor((rec.boat?.hull_color || "white").toLowerCase()),
        "line-width": 10,
        "line-emissive-strength": 1,
        "line-opacity": 0.2,
        "line-blur": 2
      }
    });

    // Main line layer with partial alpha fade
    const baseColor = (rec.boat?.hull_color || "white").toLowerCase();
    this.map.addLayer({
      id: sourceId,
      type: "line",
      source: sourceId,
      layout: {
        "line-join": "round",
        "line-cap": "round"
      },
      paint: {
        "line-width": 4,
        "line-emissive-strength": 1,
        "line-gradient": [
          "interpolate",
          ["linear"],
          ["line-progress"],
          0,   this.resolveColorWithAlpha(baseColor, 0),
          0.2, this.resolveColorWithAlpha(baseColor, 0.5),
          1,   this.resolveColorWithAlpha(baseColor, 1.0)
        ]
      }
    });
  }

  /**
   * onSliderInput(e)
   * Called when user manually scrubs the slider. Update current time, positions, stats, etc.
   */
  onSliderInput(e) {
    const val = parseInt(e.target.value, 10);
    this.currentTime = val;

    this.updateTimeDisplay(val);
    this.updateBoatPositions(val);
    this.updateBoatTrails(val);
    this.updateBoatStatsUI(val);

    // If user scrubs while playing, reset frame time to avoid big jumps
    if (this.playing) {
      this.lastFrameTime = performance.now();
    }
  }

  /**
   * updateTimeDisplay(timeMs)
   * Converts (timeMs - this.startTimestamp) into HH:MM:SS for display.
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
   * updateBoatPositions(timeMs)
   * For each recording, find its location nearest to timeMs, and move its marker there.
   */
  updateBoatPositions(timeMs) {
    this.recordings.forEach((rec) => {
      const marker = this.boatMarkers[rec.id];
      if (!marker) return;

      const loc = this.findNearestLoc(rec, timeMs);
      if (!loc) {
        // If no valid location at this time, move marker offscreen or hide it
        marker.setLngLat([9999, 9999]);
        return;
      }

      marker.setLngLat([
        loc.adjusted_longitude ?? loc.longitude,
        loc.adjusted_latitude  ?? loc.latitude
      ]);
    });
  }

  /**
   * updateBoatTrails(timeMs)
   * Sets each boat's trail to the last 60 seconds of movement.
   * We rely on a line-gradient to fade older positions.
   */
  updateBoatTrails(timeMs) {
    const windowStart = timeMs - 60000; // 60s behind the current time

    this.recordings.forEach((rec) => {
      const sourceId = `boat-trail-${rec.id}`;
      if (!this.map.getSource(sourceId)) return;

      // Filter locations to the [timeMs - 60s .. timeMs] window
      const coords = rec.recorded_locations
        .filter((loc) => {
          const t = new Date(loc.recorded_at).getTime();
          return (t >= windowStart && t <= timeMs);
        })
        .map((loc) => [
          loc.adjusted_longitude ?? loc.longitude,
          loc.adjusted_latitude  ?? loc.latitude
        ]);

      this.map.getSource(sourceId).setData({
        type: "Feature",
        geometry: { type: "LineString", coordinates: coords }
      });
    });
  }

  /**
   * updateBoatStatsUI(timeMs)
   * Updates each boat’s speed and heading displays to reflect the nearest location to timeMs.
   */
  updateBoatStatsUI(timeMs) {
    this.recordings.forEach((rec) => {
      const els = this.boatStatElements[rec.id];
      if (!els) return;

      const loc = this.findNearestLoc(rec, timeMs);
      if (!loc) {
        if (els.speedSpan) els.speedSpan.textContent   = "N/A";
        if (els.headingSpan) els.headingSpan.textContent = "N/A";
        return;
      }

      const speedVal = parseFloat(loc.velocity);
      const displaySpeed = isNaN(speedVal) ? "N/A" : `${speedVal.toFixed(1)} kts`;
      const displayHeading = (loc.heading != null) ? `${loc.heading}°` : "N/A";

      if (els.speedSpan)   els.speedSpan.textContent   = displaySpeed;
      if (els.headingSpan) els.headingSpan.textContent = displayHeading;
    });
  }

  /**
   * findNearestLoc(rec, timeMs)
   * Returns the location object from rec.recorded_locations that’s closest in time to timeMs.
   * Assumes rec.recorded_locations are sorted by recorded_at ascending (typical).
   */
  findNearestLoc(rec, timeMs) {
    const locs = rec.recorded_locations;
    if (!locs || locs.length === 0) return null;

    let best = null;
    let bestDiff = Infinity;

    // Naive linear search; if sorted, you can break early or do a binary search
    for (const loc of locs) {
      const t = new Date(loc.recorded_at).getTime();
      if (t > timeMs) break; // if strictly sorted ascending, an optimization
      const diff = Math.abs(timeMs - t);
      if (diff < bestDiff) {
        bestDiff = diff;
        best = loc;
      }
    }
    return best;
  }

  /**
   * togglePlayPause()
   * Called by the play/pause button. Starts or stops playback accordingly.
   */
  togglePlayPause() {
    if (!this.playing) {
      this.startPlayback();
    } else {
      this.pausePlayback();
    }
  }

  /**
   * startPlayback()
   * Begins the animation loop from the currentTime.
   */
  startPlayback() {
    this.playing = true;
    this.playPauseButtonTarget.textContent = "⏹︎"; // Show a stop/pause symbol
    this.lastFrameTime = performance.now();
    this.animationFrameId = requestAnimationFrame(this.animatePlayback.bind(this));
  }

  /**
   * pausePlayback()
   * Halts the animation without resetting the timeline.
   */
  pausePlayback() {
    this.playing = false;
    this.playPauseButtonTarget.textContent = "⏵"; // Show play symbol
  }

  /**
   * animatePlayback(timestamp)
   * Steps forward in time based on elapsed real-time, up to a max FPS, until the endTimestamp.
   */
  animatePlayback(timestamp) {
    if (!this.playing) return;

    // Throttle to ~this.maxFPS
    const frameInterval = 1000 / this.maxFPS;
    if (timestamp - this.lastFrameTime < frameInterval) {
      this.animationFrameId = requestAnimationFrame(this.animatePlayback.bind(this));
      return;
    }

    // Calculate real-time elapsed
    const elapsed = timestamp - this.lastFrameTime;
    this.lastFrameTime = timestamp;

    // Advance currentTime by (elapsed in seconds) * PLAYBACK_SPEED
    this.currentTime += (elapsed / 1000) * this.PLAYBACK_SPEED;
    if (this.currentTime > this.endTimestamp) {
      // Stop at the end (or loop if you prefer)
      this.currentTime = this.endTimestamp;
      this.pausePlayback();
    }

    // Update the slider
    this.sliderTarget.value = this.currentTime;

    // Update displays
    this.updateTimeDisplay(this.currentTime);
    this.updateBoatPositions(this.currentTime);
    this.updateBoatTrails(this.currentTime);
    this.updateBoatStatsUI(this.currentTime);

    // Loop
    this.animationFrameId = requestAnimationFrame(this.animatePlayback.bind(this));
  }

  /**
   * fitBoundsWithPadding()
   * Fits the map to the bounding box of all boats’ recorded points.
   */
  fitBoundsWithPadding() {
    const bounds = new mapboxgl.LngLatBounds();
    let foundAny = false;

    this.recordings.forEach((rec) => {
      const locs = rec.recorded_locations || [];
      locs.forEach((loc) => {
        bounds.extend([
          loc.adjusted_longitude ?? loc.longitude,
          loc.adjusted_latitude  ?? loc.latitude
        ]);
        foundAny = true;
      });
    });

    if (foundAny) {
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
  }

  /**
   * resolveCssColor(colorName)
   * Returns a basic CSS color or #fff fallback for known color names.
   */
  resolveCssColor(colorName) {
    const knownColors = [
      "white", "black", "red", "blue", "green", "yellow",
      "orange", "gray", "purple", "pink", "brown"
    ];
    return knownColors.includes(colorName) ? colorName : "#ffffff";
  }

  /**
   * resolveColorWithAlpha(colorName, alpha)
   * Returns an RGBA color string with the given alpha (0..1).
   */
  resolveColorWithAlpha(colorName, alpha) {
    // Basic mapping to actual RGBA. For more robust usage, do a dictionary or color library.
    const baseColor = this.resolveCssColor(colorName);
    if (baseColor === "white")  return `rgba(255,255,255,${alpha})`;
    if (baseColor === "black")  return `rgba(0,0,0,${alpha})`;
    if (baseColor === "red")    return `rgba(255,0,0,${alpha})`;
    if (baseColor === "blue")   return `rgba(0,0,255,${alpha})`;
    if (baseColor === "green")  return `rgba(0,128,0,${alpha})`;
    if (baseColor === "orange") return `rgba(255,165,0,${alpha})`;
    if (baseColor === "yellow") return `rgba(255,255,0,${alpha})`;
    if (baseColor === "gray")   return `rgba(128,128,128,${alpha})`;
    if (baseColor === "purple") return `rgba(128,0,128,${alpha})`;
    if (baseColor === "pink")   return `rgba(255,192,203,${alpha})`;
    if (baseColor === "brown")  return `rgba(165,42,42,${alpha})`;

    // Default fallback
    return `rgba(255,255,255,${alpha})`;
  }
}
