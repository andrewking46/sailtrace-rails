// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["message"];

    connect() {
        // Optionally, remove messages after a timeout (e.g., 5 seconds)
        setTimeout(() => {
            this.messageTargets.forEach(message => {
                message.classList.add("opacity-0", "-translate-y-4");
            });
        }, 5000);
    }

    remove(event) {
        // Remove the element after the transition ends
        event.target.remove();
    }
}
