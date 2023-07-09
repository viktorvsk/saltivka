# Roadmap

First set of tasks in the Roadmap is grouped by major goals this relay is trying to achieve with the highest priority.

## High Configurability

- [ ] Flexible retention policy
- [ ] Configuration hot reload using UI

## Clean Errors Descriptions

This section probably mostly requires NIPs to handle errors in a universal ways across different clients and servers.

## Comprehensive Tests and Documentation Coverage

- [ ] Introduce mutation testing
- [ ] Implement e2e tests
- [ ] Implement performance testing suite
- [ ] Measure real numbers for connections, latency etc using specific deployments to answer a question like "I want to handle 1000 simultaneous connections, which server should I buy?"
- [ ] Prepare resources for different kinds of deployments (articles, videos etc)
- [ ] Document Redis structures required for connections
- [ ] Create [C4 models](https://c4model.com) of the system

## Feature Rich

- [ ] https://github.com/nostr-protocol/nips/blob/master/50.md
- [ ] https://github.com/nostr-protocol/nips/blob/master/98.md
- [ ] https://github.com/nostr-protocol/nips/pull/377/files
- [ ] Backup export users events
- [ ] Long-term archiving of users events
- [ ] Cross-posting to other social networks
- [ ] Send notifications (email, SMS, kind-4 message etc) when specific events happen
- [ ] Crawl for users events on multiple relays
- [ ] Transmit events to multiple relays
- [ ] Advanced statistics and aggregations for Nostr network state
- [ ] Authorization strategies
- [ ] Chatbot for basic relay communication using Nostr client (i.e. show my profile, sign up, payments, show network statistics etc)
- [ ] Chatbot per user. For instance, if user wants to run an online shop on nostr, whenever its account gets a kind-4 message from other users, relay may answer on behalf of the user
- [ ] Spam protection

## Great Accessibility

- [ ] HTTP API to execute Nostr events
- [ ] GraphQL to execute Nostr events

Next set of tasks is more technical and non-functional

## Performance

- [ ] Use LUA scripting for heavy redis computations

## Optimized Storage

  * `kind` could probably be a 2 byte integer given that unlikely there will be more than 65k different event kinds in the nearest future
  * `created_at` could be a 4 byte integer
