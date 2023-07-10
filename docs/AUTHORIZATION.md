# Authentication and Authorization Flow

Both NIP-42 and experimental NIP-43 are supported (see [version of NIP-43](public/NIP-43.md) relevant at implementation time).

# How it works?

When a connection is initiated by a client, `AuthenticationFlow` (`app/relay/authentication_flow.rb`) is called.
it first checks for `FORCED_MIN_AUTH_LEVEL` environment variable value.
In case it is greater than zero, it means guest/anonymous connections are not allowed and clients must submit NIP-43 Fast Auth before connection is established.
If client doesn't submit valid kind-22242 event in websocket `authorization` params which server evaluates to `auth_level` greater or equal to `FORCED_MIN_AUTH_LEVEL` (using `AuthorizationRequest` job in `app/jobs/authorization_request.rb`) connection will be closed with specific reason and status code `3403`.
Keep in mind, in this scenario connection will be blocked (using redis `BLPOP` command) until the server processes the request. Timeout duration is defined with `AUTHORIZATION_TIMEOUT` environment variable.

If `FORCED_MIN_AUTH_LEVEL` is zero, it means anonymous clients are able to establish connections.
In this case WebsocketServer will try to find and process a NIP-43 Fast Auth kind-22242 event.
3 options are possible in this case:

1. **Auth event is found and invalid** — connection is closed with the reason of specific error.
2. **Auth event is found and valid** — authorization request is created, connection is **not** blocked and becomes established. Once the authorization request is processed, relevant `auth_level` will be assigned to the connection. Meanwhile client is able to perform requests using `auth_level=0`
3. **Auth event is not found** — then fallback to NIP-42 happens and `["AUTH", "<CONNECTION_ID>"]` event is sent to the client. In this case `challenge` is the connection identifier. According to NIP-42 relay may send this event at any given point in time. We only send it immediately after a connection has been established.

As soon as connection is established, the client may send any commands.
However, each command is the subject to individual `auth_level` configuration.
It is possible to allow `REQ` events for anonymous connections, publishing `EVENT` to `auth_level=2` connections and `COUNT` events only to `auth_level=4` connections (more on numbers meaning later).
This can be configured using the following environment variables: `REQUIRED_AUTH_LEVEL_FOR_REQ`, `REQUIRED_AUTH_LEVEL_FOR_EVENT`, `REQUIRED_AUTH_LEVEL_FOR_COUNT`. Note, there is no configuration for `CLOSE` event because it is considered to require the same `auth_level` as the `REQUIRED_AUTH_LEVEL_FOR_REQ` event.

# Authorization levels

Currently, authorization is planned to be handled using the concept of `auth_level`.
This is rather similar to role based access control (RBAC) where users' access is divided into some groups.
Alternative is permission-based access control (PBAC) where each individual user has their own set of granular permissions.
PBAC is more flexible than RBAC but is also more complex in implementation and operation.

Planned `auth_levels` (or roles)

| Level | Role | Descriptions | Note |
| ----- | ---- | ------------- | --- |
| 0     | Anonymous | connection is not authenticated by any pubkey | |
| 1     | Stranger  | connection is only authenticated by pubkey | |
| 2     | Guest     | connection is authenticated by pubkey which is registered on the server using email or other ways | Not implemented yet |
| 3     | Friend    | connections is authenticated by pubkey that has active (paid) subscription (may be anonymous) | Not implemented yet |
| 4     | Best Friend | connection is authenticated by pubkey which is added as a `TrustedPubkey` manually by an admin | |

Keep in mind, this model doesn't have any block-list.
There is no viable use-case for it because the model allows to organize bans on levels 2, 3 and 4.
And it does not actually make sense to ban specific pubkeys on levels 0 and 1 because it is trivial to create new pubkey.
Block lists usually make sense when something we block is relatively expensive to obtain (i.e. an email address or a phone number).

Also note, if a connection was authorized with some level, and later this value was changed (for example, pubkey was added to trusted), connection won't be changed on the fly and reconnect is required.

It is also planned to dedicate more attention to this model in future development.
This is going to be handled by introducing additional business logic on level 3 while level 2 could be treated like some kind of a "cold user base".
Meaning, if a user decided to provide you with their email, payment is already done using some personal information.
And main features are planned for level 3. There will be different strategies on how relay could be configured to get payments, like:

* Periodic subscription
* Pay per event
* Pay per traffic
* Pay per requests (with relation to "weight" of each of them)
* Pay periodically by viewing some sort of advertising
* Pay by referrals
* etc

Of course, it will take time to be implemented.

# Relevant configuration

Next configurations are relevant in scope of authentication and authorization (see [here](/docs/CONFIGURATION.md) for details):

* `AUTHORIZATION_TIMEOUT`
* `FORCED_MIN_AUTH_LEVEL`
* `REQUIRED_AUTH_LEVEL_FOR_REQ`
* `REQUIRED_AUTH_LEVEL_FOR_EVENT`
* `REQUIRED_AUTH_LEVEL_FOR_COUNT`
* `NIP_04_NIP_42_ENFORCE_KIND_4_AUTHENTICATION`
* `NIP_42_RESTRICT_CHANGE_AUTH_PUBKEY`
* `NIP_42_CHALLENGE_WINDOW_SECONDS`
* `NIP_43_FAST_AUTH_WINDOW_SECONDS`
* `NIP_42_43_SELF_URL`
* `NIP_65_KINDS_EXEMPT_OF_AUTH=10002`
