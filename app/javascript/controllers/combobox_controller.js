// app/javascript/controllers/combobox_controller.js
//
// This Stimulus controller powers the combobox input.
// It toggles the dropdown, filters options as the user types, and handles selection.
//
// Enhancements:
// - Detailed comments to explain each method for future developers.
// - ARIA attributes are set on the input for better accessibility.
// - Listens for outside clicks to automatically hide the dropdown.
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["input", "dropdown"];

    connect() {
        // Track whether the dropdown is currently visible.
        this.dropdownVisible = false;
        // Set ARIA attribute for accessibility.
        this.inputTarget.setAttribute("aria-expanded", "false");
        // Bind filtering on input events.
        this.inputTarget.addEventListener("input", this.filterOptions.bind(this));
        // Bind a handler for clicks outside of this combobox.
        this.boundHandleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener("click", this.boundHandleOutsideClick);
    }

    disconnect() {
        document.removeEventListener("click", this.boundHandleOutsideClick);
    }

    // Toggle the visibility of the dropdown when the caret button is clicked.
    toggleDropdown(event) {
        event.preventDefault();
        this.dropdownVisible ? this.hideDropdown() : this.showDropdown();
    }

    // Show the dropdown and update ARIA attributes.
    showDropdown() {
        this.dropdownVisible = true;
        this.dropdownTarget.classList.remove("hidden");
        this.inputTarget.setAttribute("aria-expanded", "true");
    }

    // Hide the dropdown and update ARIA attributes.
    hideDropdown() {
        this.dropdownVisible = false;
        this.dropdownTarget.classList.add("hidden");
        this.inputTarget.setAttribute("aria-expanded", "false");
    }

    // Filter dropdown options based on the user input.
    filterOptions() {
        const filter = this.inputTarget.value.toLowerCase();
        const options = this.dropdownTarget.querySelectorAll("li");
        let anyVisible = false;
        options.forEach(option => {
            const text = option.textContent.toLowerCase();
            if (text.includes(filter)) {
                option.style.display = "";
                anyVisible = true;
            } else {
                option.style.display = "none";
            }
        });
        // Automatically show or hide dropdown based on whether any option matches.
        anyVisible ? this.showDropdown() : this.hideDropdown();
    }

    // Handle selection of an option from the dropdown.
    selectOption(event) {
        const selectedValue = event.currentTarget.getAttribute("data-value");
        // Set the input's value to the text content of the clicked option.
        this.inputTarget.value = event.currentTarget.textContent.trim();
        this.hideDropdown();
    }

    // If a click occurs outside of the combobox, hide the dropdown.
    handleOutsideClick(event) {
        if (!this.element.contains(event.target)) {
            this.hideDropdown();
        }
    }
}
