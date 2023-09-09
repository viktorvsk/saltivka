module Nostr
  REQ_SCHEMA = JSONSchemer.schema({
    "$schema": "http://json-schema.org/draft-07/schema#",
    id: "nostr/nips/01/commands/client/REQ/",
    type: "array",
    items: [
      {const: "REQ", required: true},
      {type: "string", minLength: 1, maxLength: 64, id: "subscription_id"},
      {"$ref": "#/definitions/filter_set"}
    ],
    additionalItems: {
      "$ref": "#/definitions/filter_set"
    },
    definitions: {
      filter_set: {
        type: "object",
        id: "filters/",
        properties: {
          ids: {
            type: :array,
            id: :ids,
            items: {
              type: :string,
              minLength: 64,
              maxLength: 64
            }
          },
          authors: {
            type: :array,
            id: :authors,
            items: {
              type: :string,
              minLength: 64,
              maxLength: 64
            }
          },
          kinds: {
            type: "array",
            id: "kinds",
            minLength: 1,
            items: {type: "integer", minimum: 0, maximum: 65535}
          },
          search: {
            type: :array,
            id: :search,
            items: {type: :string}
          },
          limit: {
            type: :integer,
            minimum: 0,
            id: :limit
          },
          "#e": {
            type: :array,
            id: :tagged_events,
            items: {
              type: :string,
              minLength: 64, # Not part of NIP-11 but it doesn't make sense
              maxLength: 64
            }
          },
          "#p": {
            type: :array,
            id: :tagged_pubkeys,
            items: {
              type: :string,
              minLength: 64, # Not part of NIP-11 but it doesn't make sense
              maxLength: 64
            }
          }
        }
      }
    },
    minItems: 3,
    maxItems: RELAY_CONFIG.max_filters + 2
  }.to_json)

  CLOSE_SCHEMA = JSONSchemer.schema({
    "$schema": "http://json-schema.org/draft-07/schema#",
    id: "nostr/nips/01/commands/client/CLOSE/",
    type: "array",
    items: [
      {const: "CLOSE", required: true},
      {type: "string", minLength: 1, maxLength: 64, id: "subscription_id"}
    ],
    minItems: 2,
    maxItems: 2
  }.to_json)

  EVENT_SCHEMA = JSONSchemer.schema({
    "$schema": "http://json-schema.org/draft-07/schema#",
    id: "nostr/nips/01/commands/client/EVENT/",
    type: "array",
    items: [
      {const: "EVENT", required: true},
      {
        type: "object",
        id: "event/",
        properties: {
          content: {
            type: "string",
            id: "content",
            maxLength: RELAY_CONFIG.max_content_length
          },
          created_at: {
            type: "intger",
            id: "created_at",
            minimum: 0
          },
          id: {
            type: "string",
            id: "id",
            minLength: 64,
            maxLength: 64
          },
          kind: {
            type: "integer",
            id: "kind",
            minimum: 0,
            maxumum: 65535
          },
          pubkey: {
            type: "string",
            id: "pubkey",
            minLength: 64,
            maxLength: 64
          },
          sig: {
            type: "string",
            id: "sig",
            minLength: 128,
            maxLength: 128
          },
          tags: {
            type: "array",
            id: "tags/",
            items: [
              {
                type: "array",
                prefixItems: {
                  type: "string",
                  minLength: 1
                },
                minLength: 1
              }
            ],
            maxItems: RELAY_CONFIG.max_event_tags
          }
        },
        required: %w[content created_at id kind pubkey sig tags]
      }
    ],
    minItems: 2,
    maxItems: 2
  }.to_json)

  # TODO: refactor later because its completely similar to REQ schema
  # except for `id`
  COUNT_SCHEMA = JSONSchemer.schema({
    "$schema": "http://json-schema.org/draft-07/schema#",
    id: "nostr/nips/01/commands/client/COUNT/",
    type: "array",
    items: [
      {const: "COUNT", required: true},
      {type: "string", minLength: 1, maxLength: 64, id: "subscription_id"},
      {"$ref": "#/definitions/filter_set"}
    ],
    additionalItems: {
      "$ref": "#/definitions/filter_set"
    },
    definitions: {
      filter_set: {
        type: "object",
        id: "filters/",
        properties: {
          ids: {
            type: :array,
            id: :ids,
            items: {
              type: :string,
              minLength: 64,
              maxLength: 64
            }
          },
          authors: {
            type: :array,
            id: :authors,
            items: {
              type: :string,
              minLength: 64,
              maxLength: 64
            }
          },
          kinds: {
            type: "array",
            id: "kinds",
            minLength: 1,
            items: {type: "integer", minimum: 0}
          },
          search: {
            type: :array,
            id: :search,
            items: {type: :string}
          },
          limit: {
            type: :integer,
            minimum: 1,
            id: :limit
          },
          "#e": {
            type: :array,
            id: :tagged_events,
            items: {
              type: :string,
              minLength: 64,
              maxLength: 64
            }
          },
          "#p": {
            type: :array,
            id: :tagged_pubkeys,
            items: {
              type: :string,
              minLength: 64,
              maxLength: 64
            }
          }
        }
      }
    },
    minItems: 3,
    maxItems: RELAY_CONFIG.max_filters + 2
  }.to_json)
end
