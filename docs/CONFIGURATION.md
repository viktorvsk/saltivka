# Configuration

Environment variables are used to manage how the relay works.
`.env.example` contains complete list of possible settings with their default values
Some settings are used for deployment, i.e. database URL or number of processes for application server.
Some settings are used to control business logic and supported NIPs.
Here we will discuss business logic settings.

| Variable | Description | Default value | Notes |
| -----  | ----------- | ------------- | ------- |
| DEFAULT\_ERRORS\_FORMAT| other option is JSON or "as is"  | TEXT | experimental |
| AUTHORIZATION\_TIMEOUT| when NIP-43 min auth_level > 0 connection is blocked until authorization request is processed. This value defines timeout in seconds | 10 |  |
| FORCED\_MIN\_AUTH\_LEVEL| Authorization is implemented in levels, see [here](/docs/AUTHORIZATION.md) for more details | 0 |  |
| REQUIRED\_AUTH\_LEVEL\_FOR\_REQ| min `auth_level` to execute `REQ` events | 0 | same applies to `CLOSE` events |
| REQUIRED\_AUTH\_LEVEL\_FOR\_EVENT| min `auth_level` to execute `EVENT` events | 0 | |
| REQUIRED\_AUTH\_LEVEL\_FOR\_COUNT| min `auth_level` to execute `COUNT` events | 0 | |
| MAILER\_DEFAULT\_FROM| system emails will be sent on behalf of this address | admin@nostr.localhost | |
| DEFAULT\_FILTER\_LIMIT| If filters in `REQ` event do not have `limit` this values applies  | 100 | |
| VALIDATE\_ID\_ON\_SERVER| whether to validate `payload` matches `id` on the server | true | This is already checked by WebsocketServer and is time-consuming but for consistency it is enabled by default  |
| VALIDATE\_SIG\_ON\_SERVER| whether to validate `sig` matches `id` on the server | true | This is already checked by WebsocketServer and is time-consuming but for consistency it is enabled by default |
| NIP\_1\_12\_AVAILABLE\_FILTERS| Chose which tags to index and allow searching/matching | kinds ids authors #e #p since until #a #b #c #d #f #g #h #i #j #k #l #m #n #o #q #r #s #t #u #v #w #x #y #z #A #B #C #D #E #F #G #H #I #J #K #L #M #N #O #P #Q #R #S #T #U #V #W #X #Y #Z | experimental |
| NIP\_04\_NIP\_42\_ENFORCE\_KIND\_4\_AUTHENTICATION| If enforced, kind-4 events will only be sent by relay to those subscribers who are authenticated and have pubkey matching event's author pubkey or event's' p-tag | true | Delegation is not handled here |
| NIP\_11\_MAX\_FILTER\_LIMIT| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | 1000 | |
| NIP\_11\_RELAY\_NAME| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) |  | |
| NIP\_11\_DESCRIPTION| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) |  | |
| NIP\_11\_PUBKEY| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) |  | |
| NIP\_11\_CONTACT| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) |  | |
| NIP\_11\_RELAY\_COUNTRIES| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | UK UA US | |
| NIP\_11\_LANGUAGE\_TAGS| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | en en-419 | |
| NIP\_11\_TAGS| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) |  | |
| NIP\_11\_POSTING\_POLICY| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) |  | |
| NIP\_11\_MAX\_SUBSCRIPTIONS| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | 20 | |
| NIP\_11\_MAX\_FILTERS| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | 100 | |
| NIP\_11\_MIN\_PREFIX| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | 4 | |
| NIP\_11\_MAX\_EVENT\_TAGS| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | 100 | |
| NIP\_11\_MAX\_CONTENT\_LENGTH| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | 8196 | |
| NIP\_11\_MAX\_MESSAGE\_LENGTH| see [NIP-11](https://github.com/nostr-protocol/nips/blob/master/11.md) | 16384 | |
| NIP\_12\_MAX\_SEARCHABLE\_TAG\_VALUE\_LENGTH| single letter tags with value longer than this value won't be indexed  | 1000  |
| NIP\_13\_MIN\_POW| Validate event `id` have minimum difficulty | 0 | |
| NIP\_22\_CREATED\_AT\_IN\_PAST| number of seconds of how old event may be | 31556952 # 1 year | |
| NIP\_22\_CREATED\_AT\_IN\_FUTURE| number of seconds of how far in future event may be | 7889238 # 3 months | |
| NIP\_42\_RESTRICT\_CHANGE\_AUTH\_PUBKEY| should it be possible to send different kind-22242 singed by different keys to change already authenticate pubkey | false | if disabled, clients should reconnect to authenticate other pubkey |
| NIP\_42\_CHALLENGE\_WINDOW\_SECONDS| how much time NIP-42 auth challenge is valid for in seconds | 600 | |
| NIP\_43\_FAST\_AUTH\_WINDOW\_SECONDS| how much time client has between generating kind-22242 event and using it for authentication | 80 | |
| NIP\_42\_43\_SELF\_URL| This should be equal to what users will add to their clients | ws://localhost:3000 | In fact, only host name is used for validation but this should be a valid URL |
| NIP\_65\_KINDS\_EXEMPT\_OF\_AUTH| Consider min auth_level enforced is 4 but we still want NIP-65 events to pass through. Here we define space delimited kinds we allow processing without authorization | 10002 | in case min auth_level  enforced > 0 it won't work because connection won't even be established, space delimited |
| ADMIN\_EMAIL| if specified, user with this email will be created as admin who can sign in using UI to view admin dashboard |  | only works once |
| ADMIN\_PASSWORD| password for this user |  | only works once |
| TRUSTED\_PUBKEYS| list of pubkeys that will have highest auth_level=4 |  | space delimited, only works once |
