import { Controller } from "@hotwired/stimulus"

const GEOLOCATION_ERRORS = {
  TIMEOUT: 'Timeout occurred while getting geolocation.',
  PERMISSION_DENIED: 'Geolocation permission was denied.',
  POSITION_UNAVAILABLE: 'Geolocation position is unavailable.',
  UNSUPPORTED: 'Geolocation is not supported by this browser.',
};

export default class extends Controller {
  static targets = ["locationWarning", "startButton", "timeZoneInput", "form"]

  connect() {
    this.initializeGeolocation();
  }

  async initializeGeolocation() {
    if (!navigator.geolocation) {
      this.logError(GEOLOCATION_ERRORS.UNSUPPORTED);
      return;
    }

    this.timeZoneInputTarget.value = Intl.DateTimeFormat().resolvedOptions().timeZone;

    try {
      const result = await navigator.permissions.query({ name: "geolocation" });
      this.handleGeolocationPermission(result.state);
      result.onchange = () => this.handleGeolocationPermission(result.state);
    } catch (error) {
      this.logError("Error while querying geolocation permissions:", error);
    }
  }

  handleGeolocationPermission = (state) => {
    switch (state) {
      case "granted":
        this.handleGrantedState();
        break;
      case "prompt":
        this.handlePromptState();
        break;
      case "denied":
        this.handleDeniedState();
        break;
      default:
        console.error("Unknown geolocation permission state:", state);
        break;
    }
  }

  requestLocation = () => {
    navigator.geolocation.getCurrentPosition(
      this.handleSuccess,
      this.handleError,
      { enableHighAccuracy: true, timeout: 5000, maximumAge: 1000 }
    );
  }

  handleSuccess = ({ coords }) => {
    this.toggleLocationWarning(false);
    this.startButtonTarget.disabled = false;
  }

  handleError = (error) => {
    this.toggleLocationWarning(true);
    this.startButtonTarget.disabled = true;
    this.logError(GEOLOCATION_ERRORS[error.code] || "An unknown geolocation error occurred.");
  }

  handleGrantedState = () => {
    this.toggleLocationWarning(false);
    this.validateForm();
    this.requestLocation();
  }

  handlePromptState = () => {
    this.toggleLocationWarning(true);
    this.startButtonTarget.disabled = true;
  }

  handleDeniedState = () => {
    this.toggleLocationWarning(true);
    this.startButtonTarget.disabled = true;
  }

  logError = (message, error = null) => {
    console.error(message, error);
  }

  toggleLocationWarning = (show) => {
    this.locationWarningTarget.hidden = !show;
    this.locationWarningTarget.style.display = show ? 'block' : 'none';
  }

  validateForm = () => {
    const isFormValid = this.formTarget.checkValidity();
    const isLocationGranted = !this.locationWarningTarget.hidden;
    this.startButtonTarget.disabled = !(isFormValid && isLocationGranted);
  }
}
