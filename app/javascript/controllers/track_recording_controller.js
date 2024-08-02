import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pauseButton", "beacon", "gpsWarning", "consoleLog"]
  static values = { recordingId: Number }
  static ACCEPTABLE_ACCURACY_THRESHOLD = 10;
  static BATCH_SIZE = 10;
  static BATCH_INTERVAL = 30000; // 30 seconds
  static MAX_QUEUE_SIZE = 1000; // Maximum number of locations to store

  connect() {
    this.isRecording = true;
    this.locationQueue = this.loadQueueFromLocalStorage();
    this.startLocationTracking();
    this.initializeWakeLock();
    this.toggleRecording(this.isRecording);
    this.startBatchProcessing();
  }

  startLocationTracking() {
    if (!this.watchId) {
      this.watchId = navigator.geolocation.watchPosition(
        this.handleSuccess.bind(this),
        this.handleError.bind(this),
        { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 }
      );
    }
  }

  async initializeWakeLock() {
    if ('wakeLock' in navigator) {
      await this.requestWakeLock();
    } else {
      this.printLog('Screen Wake Lock API not supported.');
    }
  }

  async requestWakeLock() {
    try {
      this.wakeLock = await navigator.wakeLock.request('screen');
      this.wakeLock.addEventListener('release', async () => {
        // Attempt to reacquire the wake lock if it's released
        await this.requestWakeLock();
      });
    } catch (error) {
      this.printLog(`Screen wake lock error: ${error}`);
    }
  }

  handleSuccess = ({ coords, timestamp }) => {
    const { latitude, longitude, accuracy } = coords;
    this.updateGPSWarning(accuracy);
    this.updateBeacon(accuracy);

    if (this.isRecording && accuracy <= this.constructor.ACCEPTABLE_ACCURACY_THRESHOLD) {
      this.queueLocation({
        latitude,
        longitude,
        accuracy,
        recorded_at: new Date(timestamp).toISOString()
      });
    }
  }

  updateGPSWarning = (accuracy) => {
    this.gpsWarningTarget.hidden = accuracy <= this.constructor.ACCEPTABLE_ACCURACY_THRESHOLD;
  }

  updateBeacon = (accuracy) => {
    const isAcceptableAccuracy = accuracy <= this.constructor.ACCEPTABLE_ACCURACY_THRESHOLD;
    this.beaconTarget.classList.toggle('pulse-red', !isAcceptableAccuracy);
    this.beaconTarget.classList.toggle('pulse-green', isAcceptableAccuracy);
  }

  queueLocation = (location) => {
    this.locationQueue.push(location);
    if (this.locationQueue.length > this.constructor.MAX_QUEUE_SIZE) {
      this.locationQueue.shift(); // Remove oldest location if queue is too large
    }
    this.saveQueueToLocalStorage();
    this.printLog(`Location queued. Queue size: ${this.locationQueue.length}`);

    if (this.locationQueue.length >= this.constructor.BATCH_SIZE) {
      this.processBatch();
    }
  }

  startBatchProcessing = () => {
    this.batchInterval = setInterval(() => {
      if (this.locationQueue.length > 0) {
        this.processBatch();
      }
    }, this.constructor.BATCH_INTERVAL);
  }

  processBatch = async () => {
    if (this.locationQueue.length === 0) return;

    const batch = this.locationQueue.splice(0, this.constructor.BATCH_SIZE);
    this.saveQueueToLocalStorage();

    try {
      const response = await this.postLocationBatch(batch);
      if (response.ok) {
        this.printLog(`Batch of ${batch.length} locations saved successfully`);
      } else {
        throw new Error('Failed to save batch');
      }
    } catch (error) {
      this.printLog(`Error saving batch: ${error.message}`);
      // Put the locations back in the queue
      this.locationQueue.unshift(...batch);
      this.saveQueueToLocalStorage();
      // Implement exponential backoff for retries
      await this.retryWithBackoff(() => this.processBatch());
    }
  }

  retryWithBackoff = async (fn, maxRetries = 5, delay = 1000) => {
    for (let i = 0; i < maxRetries; i++) {
      try {
        return await fn();
      } catch (error) {
        if (i === maxRetries - 1) throw error;
        await new Promise(resolve => setTimeout(resolve, delay));
        delay *= 2; // Exponential backoff
      }
    }
  }

  postLocationBatch = async (batch) => {
    return fetch(`/recordings/${this.recordingIdValue}/recorded_locations`, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.getCSRFToken(),
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ recorded_locations: batch })
    });
  }

  loadQueueFromLocalStorage = () => {
    try {
      const queueJson = localStorage.getItem(`locationQueue_${this.recordingIdValue}`);
      return queueJson ? JSON.parse(queueJson) : [];
    } catch (error) {
      console.error('Error loading queue from localStorage:', error);
      return [];
    }
  }

  saveQueueToLocalStorage = () => {
    try {
      localStorage.setItem(`locationQueue_${this.recordingIdValue}`, JSON.stringify(this.locationQueue));
    } catch (error) {
      console.error('Error saving queue to localStorage:', error);
      // Handle full or disabled localStorage
      this.printLog('Warning: Unable to save location queue to local storage.');
    }
  }

  handleError = (error) => {
    this.gpsWarningTarget.hidden = false;
    switch(error.code) {
      case error.PERMISSION_DENIED:
        this.printLog("Geolocation permission denied. Please enable location services.");
        break;
      case error.POSITION_UNAVAILABLE:
        this.printLog("Location information is unavailable. Please check your device settings.");
        break;
      case error.TIMEOUT:
        this.printLog("The request to get user location timed out. Please try again.");
        break;
      default:
        this.printLog(`An unknown error occurred: ${error.message}`);
    }
  }

  printLog = (message) => {
    this.consoleLogTarget.textContent = message;
    console.log(message); // Also log to console for debugging
  }

  getCSRFToken = () => {
    return document.querySelector('meta[name="csrf-token"]').getAttribute('content');
  }

  toggleRecording = (isRecording) => {
    this.pauseButtonTarget.textContent = isRecording ? 'Pause recording' : 'Resume recording';
    this.beaconTarget.classList.toggle('is-recording', isRecording);
  }

  toggleRecordingAction = () => {
    this.isRecording = !this.isRecording;
    this.toggleRecording(this.isRecording);
  }

  clearWatch = () => {
    if (this.watchId) {
      navigator.geolocation.clearWatch(this.watchId);
      this.watchId = null;
    }
  }

  confirmEndRecording = async () => {
    if (confirm("Are you sure you want to end this recording?")) {
      await this.processBatch();
      await this.endRecording();
    }
  }

  endRecording = async () => {
    try {
      const response = await fetch(`/recordings/${this.recordingIdValue}/end`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': this.getCSRFToken(),
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) throw new Error('Network response was not ok');

      this.cleanup();
      window.location.href = `/recordings/${this.recordingIdValue}/processing`;
    } catch (error) {
      console.error('Error ending recording:', error);
      this.printLog('Failed to end recording. Please try again.');
    }
  }

  cleanup = () => {
    this.clearWatch();
    clearInterval(this.batchInterval);
    localStorage.removeItem(`locationQueue_${this.recordingIdValue}`);
    if (this.wakeLock) {
      this.wakeLock.release().catch(console.error);
      this.wakeLock = null;
    }
  }

  disconnect() {
    this.cleanup();
  }
}
