import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pauseButton", "beacon", "gpsWarning", "consoleLog"]
  static values = { recordingId: Number }
  static ACCEPTABLE_ACCURACY_THRESHOLD = 50;

  connect() {
    this.isRecording = true;
    this.startLocationTracking();
    this.initializeWakeLock();
    this.toggleRecording(this.isRecording);
  }

  startLocationTracking() {
    if (!this.watchId) {
      this.watchId = navigator.geolocation.watchPosition(
        position => this.handleSuccess(position),
        error => this.handleError(error),
        { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 }
      );
    }
  }

  initializeWakeLock() {
    if ('wakeLock' in navigator) {
      this.requestWakeLock();
    } else {
      this.printLog('Screen Wake Lock API not supported.');
    }
  }

  requestWakeLock() {
    navigator.wakeLock.request('screen').then(wakeLock => {
      this.wakeLock = wakeLock;
    }).catch(error => {
      this.printLog(`Screen wake lock error: ${error}`);
    });
  }

  handleSuccess({ coords }) {
    this.updateGPSWarning(coords.accuracy);
    this.printLog(`Location recorded with accuracy: ${coords.accuracy}m`);

    if (this.isRecording && coords.accuracy <= this.constructor.ACCEPTABLE_ACCURACY_THRESHOLD) {
      this.postLocationData(coords);
    }
  }

  updateGPSWarning(accuracy) {
    this.gpsWarningTarget.hidden = accuracy <= this.constructor.ACCEPTABLE_ACCURACY_THRESHOLD;
  }

  postLocationData({ latitude, longitude, speed: velocity, heading, accuracy }) {
    fetch(`/recordings/${this.recordingIdValue}/recorded_locations`, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.getCSRFToken(),
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ recorded_location: { latitude, longitude, velocity, heading, accuracy } })
    })
    .then(response => this.checkResponse(response))
    .then(data => this.printLog('Location recorded:', data))
    .catch(error => this.logError(error));
  }

  handleError(error) {
    this.toggleLocationWarning(true);
    this.printLog(`ERROR(${error.code}): ${error.message}`);
  }

  printLog(message) {
    this.consoleLogTarget.textContent += `${message}\n`;
    this.consoleLogTarget.scrollTop = this.consoleLogTarget.scrollHeight;
  }

  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]').getAttribute('content');
  }

  toggleRecording(isRecording) {
    this.pauseButtonTarget.textContent = isRecording ? 'Pause recording' : 'Resume recording';
    this.beaconTarget.classList.toggle('is-recording', isRecording);
  }

  toggleRecordingAction() {
    this.isRecording = !this.isRecording;
    this.toggleRecording(this.isRecording);
  }

  clearWatch() {
    if (this.watchId) {
      navigator.geolocation.clearWatch(this.watchId);
      this.watchId = null;
    }
  }

  confirmEndRecording() {
    if (confirm("Are you sure you want to end this recording?")) {
      this.endRecording();
    }
  }

  endRecording() {
    fetch(`/recordings/${this.recordingIdValue}/end`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': this.getCSRFToken(),
        'Content-Type': 'application/json'
      }
    })
    .then(response => this.checkResponse(response))
    .then(() => {
      this.clearWatch();
      window.location.href = `/recordings/${this.recordingIdValue}`;
    })
    .catch(error => this.logError(error));
  }

  disconnect() {
    this.clearWatch();
    if (this.wakeLock) {
      this.wakeLock.release().catch(this.logError);
      this.wakeLock = null;
    }
  }

  checkResponse(response) {
    if (!response.ok) throw new Error('Network response was not ok');
    return response.json();
  }

  logError(error) {
    console.error('Error:', error);
  }
}
