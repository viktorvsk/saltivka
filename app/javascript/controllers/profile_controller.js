import { Controller } from "@hotwired/stimulus"
import { nip19 } from "nostr-tools"

export default class extends Controller {
  connect() {
    // Get the CSRF token from the meta tag
    const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

    // Set the CSRF token as a default header for all requests
    this.headers = { "X-CSRF-Token": csrfToken, "Content-Type": "application/json" };

    if (!window.nostr) { 
      document.getElementById("nip-07-sign-event").setAttribute("disabled", "disabled");
      document.getElementById("nip-07-sign-nip-43-event").setAttribute("disabled", "disabled");
    }
    
  }

  resetForm() {
    this.element.reset();
   }

 async signAuthEvent(event) {
  event.preventDefault();
  if (window.nostr) {
    const authEvent = await nostr.signEvent({
      created_at: Math.floor((new Date()).getTime() / 1000),
      kind: 22242,
      content: "",
      tags: [
        ["relay", event.target.dataset.relay],
        ["challenge", event.target.dataset.challenge]
      ],

    })

    document.getElementById("pubkey").value = authEvent.pubkey;
    document.getElementById("signature").value = JSON.stringify(authEvent);
  }
 }

  async signAuthEventForNip43(event) {
    event.preventDefault();
    if (window.nostr) {
      const authEvent = await nostr.signEvent({
        created_at: Math.floor((new Date()).getTime() / 1000),
        kind: 22242,
        content: "",
        tags: [
          ["relay", event.target.dataset.relay],
        ],

      })

      const payload = JSON.stringify(authEvent)

      document.getElementById("nip_43_signature").value = payload;
      this.updateTemporaryRelayURL(event.target.dataset.relay, payload)
    }
  }

  updateNip43RelayUrl(event) {
    this.updateTemporaryRelayURL(event.target.dataset.relay, event.target.value);
  }

  updateTemporaryRelayURL(relayURL, payload) {
    document.getElementById("nip-43-url").innerText = `${relayURL}?authorization=${encodeURIComponent(payload)}`
  }

  convertPubkey(event) {
    if (event.target.value.match("^npub")) {
      const {data} = nip19.decode(event.target.value)
      event.target.value = data
    }
  }

}
