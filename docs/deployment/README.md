# Considerations for Deployment

Deploying to a single server for staging or personal use (e.g., personal notes backups) should be simple.

However, deploying an instance that needs to handle thousands of simultaneous connections with a large database, high throughput and low latency for aggregation (`COUNT`) requests is more complex.
There are many ways to achieve it though.

Ruby, Rails, concurrency, and relational databases are sometimes seen as slow and not scalable. While this is not generally true, it means that deployment and operations should be handled carefully.
This setup may require higher _cost per connection_ compared to a specialized implementation with a custom database and C-based websocket server.

On the other hand, PostgreSQL and Redis are widely used and have excellent support and reliability.
They can scale vertically or horizontally for a very long time, unless there are cost constraints.

The easiest solutions to manage would be to use managed databases like RDS and MemoryDB on AWS.
Combined with load balancers and horizontally scaled application servers, this setup should be able to handle a fairly large number of users.

However, managed environments will be more expensive and will still require attention, so this option should be carefully considered.
In case high workloads are expected, it is advisable to consult with experienced developers and administrators on how to better achieve your goals.

## Planned Deployment Scenariors to be Covered with Examples

### Local development

For those who wan to contribute. Details in [README](/README.md#ruby-development)

### Docker Compose

For those who want to try Saltivka as soon as possible without having to manage all the dependencies.
Details in [README](/README.md#docker-compose-demo)

### Docker Swarm (using Caprover)

For those who want to actually run small-to-medium size live server.

##### Single Server Mode

TBD

##### Cluster Mode

TBD

### k3s

TBD

### Serverless (using AWS through Terraform)

