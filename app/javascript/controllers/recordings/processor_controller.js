import { Controller } from "@hotwired/stimulus"

/**
 * ProcessorController manages the recording processing status and progress bar animation.
 */
export default class ProcessorController extends Controller {
  static targets = ["progress", "status"]
  static values = {
    id: String,
    maxRetries: { type: Number, default: 5 },
    initialDelay: { type: Number, default: 5000 },
    maxBackoff: { type: Number, default: 30000 },
    checkInterval: { type: Number, default: 2000 }
  }

  /**
   * Initialize controller state
   */
  connect() {
    this.abortController = new AbortController()
    this.retryCount = 0
    this.currentProgress = 0
    this.isProcessingComplete = false
    this.animateProgress(0, 50, this.initialDelayValue, () => this.startStatusChecks())
  }

  /**
   * Clean up resources when the controller is disconnected
   */
  disconnect() {
    this.abortController.abort()
    this.cancelAllTimers()
  }

  /**
   * Animate progress bar from start to end percentage over a given duration
   * @param {number} start - Starting percentage
   * @param {number} end - Ending percentage
   * @param {number} duration - Animation duration in milliseconds
   * @param {Function} [callback] - Optional callback function to run after animation
   */
  animateProgress(start, end, duration, callback) {
    const startTime = performance.now()
    const animate = (currentTime) => {
      const elapsedTime = currentTime - startTime
      const progress = Math.min(end, start + (elapsedTime / duration) * (end - start))
      this.updateProgress(progress)

      if (progress < end) {
        this.animationId = requestAnimationFrame(animate)
      } else if (callback) {
        callback()
      }
    }
    this.animationId = requestAnimationFrame(animate)
  }

  /**
   * Start periodic status checks
   */
  startStatusChecks() {
    this.checkStatus()
  }

  /**
   * Check the status of the recording
   */
  async checkStatus() {
    if (this.abortController.signal.aborted || this.isProcessingComplete) return

    try {
      const data = await this.fetchStatus()
      this.updateUI(data)

      if (data.status === 'processed') {
        this.handleCompletion()
      } else {
        this.handleIncompleteStatus()
      }
    } catch (error) {
      this.handleError(error)
    }
  }

  /**
   * Fetch the status from the server
   * @returns {Promise<Object>} The parsed JSON data
   */
  async fetchStatus() {
    const response = await fetch(`/recordings/${this.idValue}/status`, {
      signal: this.abortController.signal
    })
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    return response.json()
  }

  /**
   * Update the UI with the latest status
   * @param {Object} data - The status data
   */
  updateUI(data) {
    this.statusTarget.textContent = data.message
    this.incrementProgress()
  }

  /**
   * Handle the completion of the processing
   */
  handleCompletion() {
    this.isProcessingComplete = true
    this.animateProgress(this.currentProgress, 100, 2000, () => {
      console.log("Processing completed. Redirecting to recording page.")
      window.location.href = `/recordings/${this.idValue}`
    })
  }

  /**
   * Handle incomplete status by scheduling the next check
   */
  handleIncompleteStatus() {
    this.retryCount = 0 // Reset retry count on successful request
    this.scheduleNextCheck(this.checkIntervalValue)
  }

  /**
   * Increment progress bar by 10% up to 80%
   */
  incrementProgress() {
    const newProgress = Math.min(80, this.currentProgress + 10)
    this.animateProgress(this.currentProgress, newProgress, 500)
  }

  /**
   * Schedule the next status check
   * @param {number} delay - The delay before the next check
   */
  scheduleNextCheck(delay) {
    console.log(`Processing not completed. Checking again in ${delay / 1000} seconds.`)
    this.timeoutId = setTimeout(() => this.checkStatus(), delay)
  }

  /**
   * Handle errors during the status check
   * @param {Error} error - The error that occurred
   */
  handleError(error) {
    if (error.name === 'AbortError') {
      console.log('Fetch aborted')
      return
    }

    this.retryCount++
    console.error('Error checking recording status:', error)

    if (this.retryCount > this.maxRetriesValue) {
      this.showMaxRetriesError()
      return
    }

    const backoffTime = this.calculateBackoff()
    const errorMessage = error instanceof TypeError
      ? 'Network error. Retrying...'
      : `Error checking status. Retrying in ${backoffTime / 1000} seconds...`

    this.statusTarget.textContent = errorMessage
    this.scheduleNextCheck(backoffTime)
  }

  /**
   * Show max retries error message with a link to the Recordings index
   */
  showMaxRetriesError() {
    this.statusTarget.innerHTML = `
      Max retries reached. Please
      <a href="/recordings" class="text-blue-500 hover:underline">
        Back to Recordings
      </a>.
    `
  }

  /**
   * Calculate the backoff time for retries
   * @returns {number} The backoff time in milliseconds
   */
  calculateBackoff() {
    return Math.min(this.maxBackoffValue, this.checkIntervalValue * Math.pow(2, this.retryCount))
  }

  /**
   * Update the progress bar width
   * @param {number} progress - The progress percentage
   */
  updateProgress(progress) {
    this.progressTarget.style.width = `${progress}%`
    this.currentProgress = progress
  }

  /**
   * Cancel all ongoing timers and animations
   */
  cancelAllTimers() {
    if (this.timeoutId) clearTimeout(this.timeoutId)
    if (this.animationId) cancelAnimationFrame(this.animationId)
  }
}
