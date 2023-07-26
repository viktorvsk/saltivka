# Configuration

Environment variables are used to manage how the relay works.
`.env.example` contains complete list of possible settings with their default values
Some settings are used for deployment, i.e. database URL or number of processes for application server.
Some settings are used to control business logic and supported NIPs.
First let's discuss business logic settings.

| Variable | Description | Default value | Notes |
| -----  | ----------- | ------------- | ------- |
| HEARBEAT_INTERVAL | amount of time connections are allowed to be idle | 1200 | seconds |
| RATE\_LIMITING_SLIDING\_WINDOW | requests are counted during this amount of time | 60 | seconds |
| RATE\_LIMITING_MAX\_REQUESTS | so many requests are available during time window | 300 | per IP address |
| DEFAULT\_ERRORS\_FORMAT| other option is JSON or "as is"  | TEXT | experimental |
| AUTHORIZATION\_TIMEOUT| when NIP-43 min auth_level > 0 connection is blocked until authorization request is processed. This value defines timeout in seconds | 10 | seconds |
| FORCED\_MIN\_AUTH\_LEVEL| Authorization is implemented in levels, see [here](/docs/AUTHORIZATION.md) for more details | 0 |  |
| REQUIRED\_AUTH\_LEVEL\_FOR\_REQ| min `auth_level` to execute `REQ` events | 0 | same applies to `CLOSE` events |
| REQUIRED\_AUTH\_LEVEL\_FOR\_EVENT| min `auth_level` to execute `EVENT` events | 0 | |
| REQUIRED\_AUTH\_LEVEL\_FOR\_COUNT| min `auth_level` to execute `COUNT` events | 0 | |
| MAILER\_DEFAULT\_FROM| system emails will be sent on behalf of this address | admin@nostr.localhost | |
| DEFAULT\_FILTER\_LIMIT| If filters in `REQ` event do not have `limit` this values applies  | 100 | |
| VALIDATE\_ID\_ON\_SERVER| whether to validate `payload` matches `id` on the server | true | This is already checked by WebsocketServer and is time-consuming but for consistency it is enabled by default  |
| VALIDATE\_SIG\_ON\_SERVER| whether to validate `sig` matches `id` on the server | true | This is already checked by WebsocketServer and is time-consuming but for consistency it is enabled by default |
| NIP\_1\_12\_AVAILABLE\_FILTERS| Chose which tags to index and allow searching/matching | kinds ids authors #e #p since until #a #b #c #d #f #g #h #i #j #k #l #m #n #o #q #r #s #t #u #v #w #x #y #z #A #B #C #D #E #F #G #H #I #J #K #L #M #N #O #P #Q #R #S #T #U #V #W #X #Y #Z | experimental |
| NIP\_04\_NIP\_42\_ENFORCE\_KIND\_4\_AUTHENTICATION| If enforced, kind-4 events will only be sent by relay to those subscribers who are authenticated and have pubkey matching event's author pubkey or event's' p-tag | true | delegation is not handled here |
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
| NIP\_12\_MAX\_SEARCHABLE\_TAG\_VALUE\_LENGTH| single letter tags with values longer than this value won't be indexed  | 1000  |
| NIP\_13\_MIN\_POW| validate event's `id` has minimum difficulty | 0 | |
| NIP\_22\_CREATED\_AT\_IN\_PAST| oldest event to be persisted | 31556952 | seconds (default is 1 year) |
| NIP\_22\_CREATED\_AT\_IN\_FUTURE| the most futuristic event to be persisted | 7889238 | seconds (default is 3 months) |
| NIP\_42\_RESTRICT\_CHANGE\_AUTH\_PUBKEY| should it be possible to send different kind-22242 singed by different keys to change already authenticated pubkey | false | if disabled, clients should reconnect to authenticate other pubkey |
| NIP\_42\_CHALLENGE\_WINDOW\_SECONDS| how much time NIP-42 auth challenge is valid for in seconds | 600 | |
| NIP\_43\_FAST\_AUTH\_WINDOW\_SECONDS| how much time client has between generating kind-22242 event and using it for authentication | 80 | |
| NIP\_42\_43\_SELF\_URL| this should be equal to what users will add to their clients | ws://localhost:3000 | in fact, only host name is used for validation but this should be a valid URL |
| NIP\_65\_KINDS\_EXEMPT\_OF\_AUTH| consider min `auth_level=4` enforced for `EVENT` commands but we still want NIP-65 events to pass through. Here we define space delimited kinds we allow processing without authorization | 10002 | in case `FORCED_MIN_AUTH_LEVEL` > 0, it won't work because connection won't even be established (space delimited list) |
| ADMIN\_EMAIL| if specified, user with this email will be created as admin who can sign in using UI to view admin dashboard |  | only works once |
| ADMIN\_PASSWORD| password for this user |  | only works once |
| TRUSTED\_PUBKEYS| list of pubkeys that will have highest `auth_level=4` |  | space delimited list, only works once |

Here lets review configuration related to payments:

| Variable | Description | Default value | Notes |
| -----  | ----------- | ------------- | ------- |
| DEFAULT\_INVOICE_AMOUNT | The value users see filled on the first page load | 6000 | sats |
| DEFAULT\_INVOICE_PERIOD | The value users see filled on the first page load | 30 | days |
| PRICE\_PER_DAY | Subscription daily price | 200 | sats |
| PROVIDER\_API_KEY\_OPEN\_NODE | Integration secret key | | |
| INVOICE_TTL | How much time users have to pay the invoice | 1200 | seconds |


Now let's briefly review general app settings:

| Variable | Description | Default value |
| ------ | ----------- |:-------------:|
| POSTGRES_USER     | DB username | postgres |
| POSTGRES_PASSWORD | DB user password |
| POSTGRES_HOST | DB host | localhost |
| POSTGRES_DATABASE | DB name | saltivka |
| POSTGRES_PORT | DB port | 5432 |
| POSTGRES_POOL | number of connections in the pool. Usually must match `RAILS_MAX_THREADS` | 5 |
| REDIS_URL | URL of Redis service for WebsocketServer and Sidekiq worker components | redis://localhost:6379 |
| RAILS\_MAX_THREADS | max number of threads per puma worker. Must be tuned responsibly but usually anything greater than 5 doesn't mean profits for puma. But keep in mind, Sidekiq worker also depends on this variable so it should be adjusted accordingly | 5 |
| RAILS\_MIN_THREADS | min number of threads per puma worker. With stable traffic its better to have `min === max`, with burst traffic `min` should be lower than `max`| 5 |
| PORT | application port | 3000 |
| PIDFILE | path to pidfile | tmp/pids/server.pid |
| WEB_CONCURRENCY | number of puma workers (processes). Usually should match number of CPU cores but on practice should be determined based on the workload and resources | 2 |
| RAILS_ENV | environment to run application, most of the time should be left default | production |
| RAILS\_SERVE\_STATIC_FILES | Make Rails serve static file in `/public` directory. Most of the time Rails should run behind reverse proxy with this parameter set to `false` and reverse proxy to serve static assets |
| RAILS_LOG\_TO\_STDOUT | logs destination |
| RAILS_LOG\_LEVEL | logs level | warn |
| SECRET\_KEY_BASE | some random secret string for sessions and other stuff |
| SENTRY_DSN | Sentry integration |
| NEW_RELIC_LICENSE_KEY= | Newrelic integration |
| NEW_RELIC_APP_NAME= | Newrelic app name |
| NEW_RELIC_LOG_LEVEL= | Newrelic logs level |
| CI | run full tests suite on CI |
| RUBY_YJIT\_ENABLE | enable YJIT for Ruby, its Docker-image-dependent, usually should be left default| true |
