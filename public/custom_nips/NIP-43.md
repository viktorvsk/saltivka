NIP-43
======

Fast Authentication
-------------------

`draft` `optional` `author:arthurfranca`

This is a `client` to `relay` authentication procedure that
happens on connection start by using an `authorization` query parameter.
For example:

`new WebSocket("wss://relay.url?authorization=...")`

## Motivation

`Relays` may want to grant access to specific resources just to authenticated users.

For that, both `clients` and `relays` need to implement authentication. A simple authentication
procedure that `clients` can easily implement (just a query parameter) is better for driving adoption.

### Access Permission Examples

- Only paying user can publish events from his pubkey and republish events from other authors to the `relay`. If not a paying user or not authenticated, reply to event publishing attempts with `"OK"` message (as per [NIP-20](20.md)) indicating failure.
- Only paying user can read from `relay`. If not a paying user or not authenticated, reply to all subscriptions with `"EOSE"`.
- When user requests a DM event from `relay`, send it only to authenticated user if he is the author or the recipient.

**Note:** "Paying user" examples could use other whitelisting means such as requiring users to have previously confirmed email or phone number or passed a CAPTCHA.

## How Clients Authenticate

The `client` must generate a `kind: 22242` ephemeral event with the current time as `created_at`
and the relay url as a `relay` tag.
Then it has to stringify the JSON event and [percent-encode](https://www.rfc-editor.org/rfc/rfc3986#page-12) it.
The resulting string is used as `authorization` query param when connecting to the relay.

### Javascript Example

```js
 const relayUrl = 'wss://relay.example.com'
 // add id and signature as usual
 const jsonEvent = generateNostrEvent({
   pubkey: "...",
   created_at: Math.floor(Date.now() / 1000),
   kind: 22242,
   tags: [['relay', relayUrl]],
   content: ""
 })
 const auth = window.encodeURIComponent(JSON.stringify(jsonEvent))
 const ws = new WebSocket(`${relayUrl}?authorization=${auth}`)
 ws.addEventListener('open', () => console.log('auth accepted'))
 ws.addEventListener('close', () => console.log('disconnected') )
```

## How Relay Handle Authentication

`Relays` authenticate users with valid `authorization` query param.

The `authorization` query param must be percent-decoded into a nostr event that must:
- be of `kind` `22242`;
- have `created_at` within a small time window relative to the current date (e.g. 60 seconds);
- have the `relay` tag url value with the same domain name as the connected `relay`.

## Security Measures

The used protocol should be `wss` (WebSocket Secure).

Although not required, the authorization event `id` can be stored by the `relay`
for the same above mentioned time window so that
if the same event `id` is used twice, the `relay` should reject the connection and
also disconnect the user that first used the event to authenticate.