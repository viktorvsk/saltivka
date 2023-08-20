# Architecture
This is mostly a typical Ruby on Rails application with FayeWebsocket server and Sidekiq for background jobs.

## Components

### Websocket server
Clients connect to the FayeWebsocket server and only communicate with it in terms of the Nostr protocol.
Websocket server assigns persistent `connection_id` to identify the client. and opens a separate connection to Redis.
Websocket server is responsible for initial validation of the system, subscriber and events, i.e.:
* Is the system in maintenance mode?
* Is max number connections to the server has not yet reached the limit?
* Is the subscriber rate-limited?
* Is NIP-43 enforced with min auth_level by configuration? Then check it or close the connection.
* Is NIP-43 not enforced? Then send NIP-42 AUTH event with challenge equal to `connection_id`
* Is message payload matches content length?
* Is message payload a valid JSON?
* Is message payload conforms to known Nostr events schemas?
* Is the subscriber authorized to execute this event?
* Does the event's payload match basic sanity checks like `since < until` in filters?

In case all validations passed and event should be processed, Websocket server populates minimal required data structures in Redis (for example creates a SET `client_reqs:<CONNECTION_ID>` with a list of provided `subscription_ids` in case of `REQ` event) and creates corresponding Sidekiq Job.


| Event | Job |
| :-----: | :----:|
| `REQ`   | `NewSubscription` |
| `CLOSE` | — |
| `EVENT` | `NewEvent` |
| `COUNT` | `CountRequest` |

At this point request processing part is finished on the WebsocketServer side and it awaits the result of the processed Sidekiq job.

Each Websocket server connection handler instance creates a separate thread where it listens to Redis [`Pub/Sub`](https://redis.io/commands/?group=pubsub) messages on channels matching pattern `events:<CONNECTION_ID>:*`.
Those messages may either be Nostr events that should be sent to the client (as is or slightly modified on Websocket server side) or a message to close connection.

WebsocketServer manages NIP-11 HTTP response.

Websocket server is also responsible for properly handling connection `close` and resources cleanup i.e. Redis data structures that belong to the `connection_id` and Redis connection created specifically for this client.
Connection may be closed due to following reasons:
* Client closed connection
* NIP-43 is forced with min auth_level but client didn't pass it
* Connection was manually closed from admin UI

### Redis
Currently [RedisStack](https://redis.io/docs/about/about-stack/) of version 6.2.6 is used because there are plans to use RedisGraph.
However, in future it is planned to use multiple different Redis instances for different components.
One Redis for Sidekiq (background jobs) — which will have the strongest persistence possible.
One for handling Pub/Sub without persistence aiming for the best throughput.
One for websocket connection business logic with a mixed performance/persitence ration goals.
One for caching solely etc.
Redis is utilized heavily here. 3 main use-cases are:
1. Pub/Sub handler
2. Websocket connection business logic
2. Background jobs

But it is also responsible to handle various data structures i.e. expiration keys and rate limiting sorted sets etc.

###### DATA STRUCTURES

| Data Structure | Type | Description |
| --- | --- | --- |
| `client_reqs:<CONNECTION_ID>` | SET | subscription_id list per connection |
| `connections` | SET | list of active connections |
| `connections_authenticators` | HASH | event kind-22242 id that validated connection |
| `subscriptions:<CONNECTION_ID>:<SUBSCRIPTION_ID>` | JSON | contains filters |
| `subscriptions_idx` | RediSearch Index (`FT.CREATE`) | indexes subscriptions for search using `FT.SEARCH` command |
| `authentications` | HASH |pubkey per connection |
| `authorizations` | HASH | `auth_level` per connection |
| `requests` | HASH | requests count per connection |
| `incoming_traffic` | HASH | incoming traffic per connection |
| `outgoing_traffic` | HASH | outgoing traffic per connection |
| `connections_ips` | HASH |IP address per connection |
| `connections_starts` | HASH | start time per connection |
| `events22242:<EVENT_22242_ID>` | EXPIRABLE STRING | indicates that the event was already used for authentications, expires when event becomes invalid |
| `maintenance` | STRING | prevents new connections, doesn't break existing |
| `unlimited_ips` | SET | list of IP addresses that won't be a subject to rate limiting |
| `max_allowed_connections` | STRING | NULL or 0 means unlimited  |
| `email_confirmations:<TOKEN>` | EXPIRABLE STRING | Used to confirm users emails on Sign Up |

###### Pubsub Messages

Main communication between WebsocketServer and other components (ApplicationServer, Sidekiq worker) is going through Redis `PUBSUB`.
It is possible to subscriber to those messages if necessary.
For example, in order to build some extension/plugin or integration.
Currently all the messages are publishied to channels of the following pattern:
```
events:<CONNECTION_ID>:<SUBSCRIPTION_ID>:<COMMAND>"
```
`SUBSCRIPTION_ID` may equal to `_` if it is not used in specific command.

See the list of commands with their Nostr equivalents and description:

| Command | Nostr Equivalent | Example Payload |
| ------- | ---------------- | ------- | ----------- |
| FOUND_END | EOSE |— |
| FOUND_EVENT | EVENT| `"{\"id\": \"...\", \"sig\": \"...\", ...}"` |
| OK | OK |`"[\"OK\", \"<MESSAGE>\"]"` |
| COUNT | COUNT | "5" |
| NOTICE | NOTICE | `"MESSAGE"` |
| TERMINATE | — | `"[4000, "<REASON>"]"` |

Keep in mind, there is no message for `AUTH` because it is handled directly in WebsocketServer and not through Redis.

###### NOTES

Choosing what actual Redis server to use and how to configure it consider the following.
Websocket server uses minimal amounts of data in Redis and its more tolerant to critical failures with the worst that can happen — clients will have to reconnect and will lose some responses.
While Sidekiq workers are more reliant on data in Redis and consume much more traffic (i.e. events payload)
The main thing to remember is the eviction policy in order not to accidentally lose some Sidekiq jobs during high peak traffic.
In theory different Redis servers should be used for WebsocketServer and for Sidekiq.
But currently this is not supported.

### Sidekiq worker
Nostr business logic is running inside of background jobs.
Those jobs may change Redis data, persist/delete Events in PostgreSQL, publish messages to redis channels with Nostr events responses or connection termination commands.

### Application server
Ruby on Rails application served by Puma application server to manage incoming requests.
Puma is responsible for routing websocket connections from clients to WebsocketServer.
It also provides admin dashboard HTTP part and any future extensions i.e.: public dashboard, user portal, HTTP API, GraphQL etc

### Database
Tested against 14,15 and 16 versions of PostgreSQL but at the moment there are no version-specific SQL so in theory many versions should be compatible.

Database currently has the following core tables: `authors`, `delete_events`, `events`, `searchable_tags`, `event_delegators`, `trusted_authors` which are slightly optimized for storage (by normalizing `authors` public keys for example).
And secondary, not Nostr-specific tables: `users`, `user_pubkeys`, `relay_mirrors`, `invoices`, `author_subscriptions`.
Proper indexing strategy is a subject to change.

## Notes on WebsocketServer implementation
This project is aimed to be as standard Ruby on Rails project as possible.
Meaning if there is a trade-off between **The Rails Way** and something else, most of the time it will be **The Rails Way** unless 20% of efforts allow to gain 80% of profit.
However, since Ruby in general and Puma/FayeWebsocket don't play really well with multi threading and WebsocketServer is the most important part in Nostr, one may want to rewrite WebsocketServer component in something more concurrency-friendly but keep the rest of the features.
To support such a potential development, Websocket server (see `app/relay`) will be implemented in the most simple way with the least amount of dependencies.
Currently main dependencies (outside of `app/relay`) are:

* `FayeWebsocket`
* `ActiveSupport`
* `Rails.logger`
* `Sentry`
* `RELAY_CONFIG`

It shouldn't be too complex to rewrite the Websocket component into another language for more efficient connection handling.
