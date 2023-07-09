# Known major limitations

* There is no way at the moment to drop jobs in progress when connection is closed during processing. For instance, if a client initiated a heavy `COUNT` event and disconnected immediately there is no way to stop execution of the job and resources will just be wasted.
* Every connection gets its own `connection_id` and there is no way now to `reconnect` (however, there is no visible use-case for it too except for some lost responses)
* There is no acknowledgement mechanism since `PUBSUB` is used and not `STREAMS` but its not clear whether it makes sense to change it in future or not
* Each client connection responses is handlel with Redis `PUBSUB` meaning each connection requires dedicated Redis connection so that redis connections can't be managed with connection pooling so there will be `redis_connections_count =  puma_pool + sidekiq_pool + subscribers_count`. It's not a problem in theory since Redis is able to handle tens of thousands of connections and may be scaled horizontally. But some providers may limit this number and  deployment at scale should account for that fact.
* Nothing has been implemented yet in terms of TOR deployment
