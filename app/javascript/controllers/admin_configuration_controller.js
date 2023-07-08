import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Get the CSRF token from the meta tag
    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

    // Set the CSRF token as a default header for all requests
    this.headers = { "X-CSRF-Token": csrfToken, "Content-Type": "application/json" };
  }

  updateDynamicConfig() {
    const value = this.element.type === "checkbox" ? this.element.checked : this.element.value
    fetch('/admin/configuration', { headers: this.headers, method: "PUT", body: JSON.stringify({configuration: { value: value, name: this.element.name}}) }).then()
  }
}
