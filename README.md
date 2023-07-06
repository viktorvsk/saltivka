# Saltivka
This is an implementation of the [Nostr protoco](https://github.com/nostr-protocol/nostr) server (Nostr Relay) in Ruby. It implements the following list of specifications (Nostr Implementation Possibilities or NIPs):

* [NIP-01: Basic protocol flow description](https://github.com/nostr-protocol/nips/blob/master/01.md)
* [NIP-04: Encrypted Direct Message](https://github.com/nostr-protocol/nips/blob/master/04.md)
* [NIP-09: Event Deletion](https://github.com/nostr-protocol/nips/blob/master/09.md)
* [NIP-11: Relay Information Document](https://github.com/nostr-protocol/nips/blob/master/11.md)
* [NIP-12: Generic Tag Queries](https://github.com/nostr-protocol/nips/blob/master/12.md)
* [NIP-13: Proof of Work](https://github.com/nostr-protocol/nips/blob/master/13.md)
* [NIP-16: Event Treatment](https://github.com/nostr-protocol/nips/blob/master/16.md)
* [NIP-20: Command Results](https://github.com/nostr-protocol/nips/blob/master/20.md)
* [NIP-22: Event `created_at` Limits](https://github.com/nostr-protocol/nips/blob/master/22.md)
* [NIP-26: Delegated Event Signing](https://github.com/nostr-protocol/nips/blob/master/26.md)
* [NIP-28: Public Chat](https://github.com/nostr-protocol/nips/blob/master/28.md)
* [NIP-33: Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md)
* [NIP-40: Expiration Timestamp](https://github.com/nostr-protocol/nips/blob/master/40.md)
* [NIP-42: Authentication of clients to relays](https://github.com/nostr-protocol/nips/blob/master/42.md)
* [NIP-43: Fast Auth (experimental)](https://github.com/nostr-protocol/nips/pull/571)
* [NIP-45: Event Counts](https://github.com/nostr-protocol/nips/blob/master/45.md)
* [NIP-65: Relay List Metadata](https://github.com/nostr-protocol/nips/blob/master/65.md)

# Abstract
Nostr requires decentralization. Decentralization requires servers. Many different servers, small and big. Some servers should be robust and cheap to operate. Some servers are better to be cute and simple to use. This relay aims to become the most developer-friendly and the most host-friendly implementation through:

* **high configurability** — like support for dynamic feature flags in future
* **clean errors descriptions** — including different formats and granular causes
* **Comprehensive tests and documentation coverage** — plans to focus on mutation and unit tests
* **feature rich** — for example, experimental NIPs and non-nostr related staff like backups, cross posting etc
* **great accessibility** — plans to add support for major integrations aka HTTP API, GraphQL, webhooks and others

The ultimiate goal is everyone using this relay for the next use-cases:

* **Developers**, while working on a client, need to connect to some relays, play with different NIPs, fix errors, check hypothesis
* **Non-technical but curious person** wants to setup a private relay to share it with friends and family
* **Small-to-medium businesses** use custom configuration of the relay to provide paid services in their specific niche (i.e. invite-driven userbase gets IT-related curated content into their feed)

This however doesn't mean it *shouldn't* be possible to serve millions of users per day with this relay. It just means that with Ruby and concurrency one will have to throw more money into hardware. So performance optimizations will usually have low priority unless it prevents some interesting use-cases. 

# Gettings started
Here you won't find any instructions on how to deploy production-ready services for millions of active connections because there are infinite amount of ways of how to achieve it and which trade-offs to choose.

Some thoughts and hints on prodiction deployment may be found [here](/docs/DEPLOYMENT.md). 2 main use-cases here described are:

1. Deployment through docker-compose with a very primitive setup to give a basic understanding on how things work together, quickly test it and potentially deploy to a single server expecting small workload
2. Local setup for development and contributions

* TBD: link to the guide on how to deploy to managed cloud environment
* TBD: link to production deployment instance

## Docker-Compose (demo)
1. Prepare a host with docker environment installed (something like [this](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04)). Demo setup expects something around 8 GB of RAM
2. SSH into this host
3. `git clone https://github.com/viktorvsk/saltivka.git`
4. `cd saltivka`
5. `docker build -t saltivka .` (TODO: this should be removed once image gets to Dockerhub)
6. `docker compose up --build --scale worker=4`

Thats it! Wait a minute or two until database is ready. Now you should have HTTP/WS server available at `localhost:3000` and HTTPS/WSS at `localhost:2402`. Ensure ports are open on your server. Both commands should work and let you start working with Nostr:

* `wscat -c "ws://localhost:3000"`
* `wscat --no-check -c "wss://localhost:2402"`

(Assuming `wscat` is installed and `localhost` is changed to the server IP if necessary.)
## Ruby (development)
Its a typical Ruby on Rails application so all defaults mostly apply.

1. `$ git clone https://github.com/viktorvsk/saltivka.git`
2. `$ cd saltivka`
3. `$ cp .env.example .env.development` (Adjust Postgres and Redis settings)
4. `$ echo POSTGRES_DATABASE=nostrails_test > .env.test`
5. Adjust Postgres and Redis credentials in `.env.test` if needed. Use databases different from development environment
6. `$ rails db:create db:migrate db:seed`
7. `$ rspec`
8. `$ rails server`
9. `$ bundle exec sidekiq -q nostr`

# Further readings
* [Configuration options](/docs/CONFIGURATION.md)
* [Architecture details](/docs/ARCHITECTURE.md)
* [Trade-offs](/docs/TRADEOFFS.md)
* [Deployment hints](/docs/DEPLOYMENT.md)
* [Roadmap](/docs/ROADMAP.md)
