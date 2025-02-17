import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["message"];

    // Store active timeout IDs for cleanup.
    timeoutIds = [];

    connect() {
        // Automatically remove messages after 5 seconds.
        this.messageTargets.forEach(message => {
            const timeoutId = setTimeout(() => {
                message.classList.add("opacity-0", "-translate-y-4");
            }, 5000);
            this.timeoutIds.push(timeoutId);
        });
    }

    disconnect() {
        // Clear any timeouts when the controller is disconnected.
        this.timeoutIds.forEach(timeoutId => clearTimeout(timeoutId));
    }

    dismiss(event) {
        event.preventDefault();
        // Find the closest flash message container.
        const message = event.target.closest('[data-flash-target="message"]');
        if (message) {
            message.classList.add("opacity-0", "-translate-y-4");
            // Remove the message after the transition completes.
            message.addEventListener("transitionend", () => {
                message.remove();
            }, { once: true });
        }
    }

    remove(event) {
        // Remove the element after the transition ends.
        event.target.remove();
    }
}
