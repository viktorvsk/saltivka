import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
  }

  toggleBurger() {
      const target = this.element.dataset.target;
      const $target = document.getElementById(target);

      this.element.classList.toggle('is-active');
      $target.classList.toggle('is-active');
  }
}
