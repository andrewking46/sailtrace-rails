import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pauseButton", "beacon", "gpsWarning", "consoleLog"]
  static values = { recordingId: Number }

  connect() {
    this.isRecording = false;
    this.toggleRecording(true);
    this.startLocationTracking();
    this.initializeWakeLock();
  }

  startLocationTracking() {
    this.watchId = navigator.geolocation.watchPosition(
      position => this.handleSuccess(position),
      error => this.handleError(error),
      { enableHighAccuracy: true, maximumAge: 5000, timeout: 10000 }
    );
    this.isRecording = true;
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

    if (coords.accuracy > 10) return;
    this.postLocationData(coords);
  }

  updateGPSWarning(accuracy) {
    this.gpsWarningTarget.hidden = accuracy <= 10;
  }

  postLocationData({ latitude, longitude, speed: velocity, heading }) {
    fetch(`/recordings/${this.recordingIdValue}/recorded_locations`, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.getCSRFToken(),
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ recorded_location: { latitude, longitude, velocity, heading } })
    })
    .then(this.checkResponse)
    .then(data => this.printLog('Location recorded:', data))
    .catch(this.logError);
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
    this.isRecording = isRecording;
    this.beaconTarget.classList.toggle('is-recording', isRecording);
    this.pauseButtonTarget.textContent = isRecording ? 'Pause recording' : 'Resume recording';
  }

  toggleRecordingAction() {
    if (this.isRecording) {
      navigator.geolocation.clearWatch(this.watchId);
    } else {
      this.startLocationTracking();
    }
    this.toggleRecording(!this.isRecording);
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
    .then(this.checkResponse)
    .then(() => window.location.href = `/recordings/${this.recordingIdValue}`)
    .catch(this.logError);
  }

  disconnect() {
    if (this.watchId) navigator.geolocation.clearWatch(this.watchId);
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
