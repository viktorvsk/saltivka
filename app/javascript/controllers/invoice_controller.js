import { Controller } from "@hotwired/stimulus"
import { nip19 } from "nostr-tools"

export default class extends Controller {
  connect() {
  }

  convertPubkey(event) {
    if (event.target.value.match("^npub")) {
      const {data} = nip19.decode(event.target.value)
      event.target.value = data
    }
  }

  recalculateDays(event) {
    document.querySelector("#invoice_amount_sats").value = event.target.value * parseInt(event.target.dataset.pricePerDay)
  }
}
