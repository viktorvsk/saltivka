# Saltivka

![Saltivka](/app/assets/images/screenshot.png)

This is an implementation of the [Nostr protocol](https://github.com/nostr-protocol/nostr) server (Nostr Relay) in Ruby. It implements the following list of specifications (Nostr Implementation Possibilities or NIPs):

* [NIP-01: Basic protocol flow description](https://github.com/nostr-protocol/nips/blob/master/01.md)
* [NIP-04: Encrypted Direct Message](https://github.com/nostr-protocol/nips/blob/master/04.md) Only authenticated pubkeys can get their own kind-4 events, uses NIP-42/NIP-43
* [NIP-05: Mapping Nostr keys to DNS-based internet identifiers](https://github.com/nostr-protocol/nips/blob/master/05.md) Allows registered users to have their own NIP-05 identifiers
* [NIP-09: Event Deletion](https://github.com/nostr-protocol/nips/blob/master/09.md)
* [NIP-11: Relay Information Document](https://github.com/nostr-protocol/nips/blob/master/11.md)
* [NIP-13: Proof of Work](https://github.com/nostr-protocol/nips/blob/master/13.md)
* [NIP-28: Public Chat](https://github.com/nostr-protocol/nips/blob/master/28.md) Treats kind 41 event as replaceable
* [NIP-40: Expiration Timestamp](https://github.com/nostr-protocol/nips/blob/master/40.md)
* [NIP-42: Authentication of clients to relays](https://github.com/nostr-protocol/nips/blob/master/42.md)
* [NIP-43: Fast Auth (experimental)](https://github.com/nostr-protocol/nips/pull/571)
* [NIP-45: Event Counts](https://github.com/nostr-protocol/nips/blob/master/45.md)
* [NIP-50: Search Capability](https://github.com/nostr-protocol/nips/blob/master/50.md)
* [NIP-65: Relay List Metadata](https://github.com/nostr-protocol/nips/blob/master/65.md) Allows configure event kinds that are not subject to access control, meaning you can always do anything with kind 10002 events

# Abstract
Nostr requires decentralization. Decentralization requires servers. Many different servers, small and big. Some servers should be robust and cheap to operate at scale. Some servers are better to be cute and simple to use. This relay aims to become the most developer-friendly and the most relay-operator-friendly implementation through:

* **high configurability** — like support for dynamic feature flags in future
* **clean errors descriptions** — including different formats and granular causes
* **comprehensive tests and documentation coverage** — plans to focus on mutation and unit tests
* **feature rich** — for example, experimental NIPs and non-nostr related stuff like backups, cross posting etc
* **great accessibility** — plans to add support for major integrations aka HTTP API, GraphQL, webhooks and others

The ultimate goal is everyone using this relay for the next use-cases:

* **developers**, while working on a client, need to connect to some relays, play with different NIPs, fix errors, check hypothesis
* **non-technical but curious people** wants to setup a private relay to share it with friends and family
* **small-to-medium businesses** use custom configuration of the relay to provide paid services in their specific niche (i.e. invite-driven userbase gets IT-related curated content into their feed)

This however doesn't mean it *shouldn't* be possible to serve millions of users per day with this relay. It just means that with Ruby and concurrency one will have to spend more money into hardware. So performance optimizations will usually have low priority unless it prevents some interesting use-cases. 

# Getting started
Here you won't find any instructions on how to deploy production-ready services for millions of active connections because there are infinite amount of ways of how to achieve it and which trade-offs to choose.

Some thoughts and hints on production deployment may be found [here](/docs/DEPLOYMENT.md). 2 main use-cases described here are:

1. Deployment through docker-compose with a very primitive setup to give a basic understanding on how things work together, quickly test it and potentially deploy to a single server expecting small workload
2. Local setup for development and contributions

* TBD: link to the guide on how to deploy to managed cloud environment
* Live instance could be found at [https://saltivka.org](https://saltivka.org) and relay address is `wss://saltivka.org`

## Docker Compose (demo)
1. Prepare a host with docker environment installed (something like [this](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-22-04)). Demo setup expects approximately 8 GB of RAM and 4vCPU
2. SSH into this host
3. ```git clone https://github.com/viktorvsk/saltivka.git```
4. ```cd saltivka```
5. ```docker-compose -f demo/docker-compose.yml up --build```

That's it! Wait a minute or two until database is ready. Now you should have HTTP/WS server available at `localhost:3000` and HTTPS/WSS at `localhost:2402`. Ensure ports are open on your server. Both commands should work and let you start working with Nostr:

* ```wscat -c "ws://localhost:3000"```
* ```wscat --no-check -c "wss://localhost:2402"```

(Assuming `wscat` is installed and `localhost` is changed to the server IP if necessary.)
## Ruby (development)
It's a typical Ruby on Rails application so all defaults mostly apply.

1. ```git clone https://github.com/viktorvsk/saltivka.git```
2. ```cd saltivka```
3. ```cp .env.example .env.development``` Copy default settings to development environment
4. ```cp .env.test.example .env.test``` Copy default settings to test environment
5. ```docker-compose -f local_dev/docker-compose.yml up``` run PostgreSQL on port `5432`, RedisStack on port `6379`, Redis (for Sidekiq) on port `63790`. **This step is optional if you prefer running those dependencies in a different way**
6. Adjust PostgreSQL and Redis connections details in `.env.test` and `.env.development` if necessary. Use different databases for development and test environments
7. ```bin/setup``` Setup dependencies and database
8. ```RAILS_ENV=test bin/setup && bin/rspec``` Run tests (optional)
9. ```bin/dev``` Start all required services

# Further reading
* [Configuration options](/docs/CONFIGURATION.md)
* [Architecture details](/docs/ARCHITECTURE.md)
* [Limitations](/docs/LIMITATIONS.md)
* [Deployment hints](/docs/deployment/README.md)
* [Contributing](/docs/CONTRIBUTING.md)
* [Search](/docs/NIP-50-SEARCH.md)
