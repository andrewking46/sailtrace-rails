import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress", "status"]
  static values = { id: String }

  connect() {
    this.checkStatus()
  }

  async checkStatus() {
    try {
      const response = await fetch(`/recordings/${this.idValue}/status`)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      const data = await response.json()

      this.updateProgress(data.completed ? 100 : 50)
      this.statusTarget.textContent = data.message

      if (data.completed) {
        console.log("Processing completed. Redirecting to recording page.")
        window.location.href = `/recordings/${this.idValue}`
      } else {
        console.log("Processing not completed. Checking again in 2 seconds.")
        setTimeout(() => this.checkStatus(), 2000)
      }
    } catch (error) {
      console.error('Error checking recording status:', error)
      this.statusTarget.textContent = 'Error checking status. Retrying...'
      setTimeout(() => this.checkStatus(), 5000)
    }
  }

  updateProgress(progress) {
    this.progressTarget.style.width = `${progress}%`
  }
}
