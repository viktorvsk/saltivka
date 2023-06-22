module Nostr
  REQ_SCHEMA = JSONSchemer.schema({
    "$schema": "http://json-schema.org/draft-07/schema#",
    id: "nostr/nips/01/commands/client/REQ/",
    type: "array",
    items: [
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
              minLength: 1,
              maxLength: 64
            }
          },
          authors: {
            type: :array,
            id: :authors,
            items: {
              type: :string,
              minLength: 1,
              maxLength: 64
            }
          },
          kinds: {
            type: "array",
            id: "kinds",
            minLength: 1,
            items: {type: "integer", minimum: 0}
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
              minLength: 1,
              maxLength: 64
            }
          },
          "#p": {
            type: :array,
            id: :tagged_pubkeys,
            items: {
              type: :string,
              minLength: 1,
              maxLength: 64
            }
          }
        }
      }
    },
    minItems: 2
    # maxLength: 100 # TODO: set max filters configurable
  }.to_json)

  CLOSE_SCHEMA = JSONSchemer.schema({
    "$schema": "http://json-schema.org/draft-07/schema#",
    id: "nostr/nips/01/commands/client/CLOSE/",
    type: "array",
    items: [
      {type: "string", minLength: 1, maxLength: 64, id: "subscription_id"}
    ],
    minItems: 1,
    maxItems: 1
  }.to_json)

  EVENT_SCHEMA = JSONSchemer.schema({
    "$schema": "http://json-schema.org/draft-07/schema#",
    id: "nostr/nips/01/commands/client/EVENT/",
    type: "array",
    items: [
      {
        type: "object",
        id: "event/",
        properties: {
          content: {
            type: "string",
            id: "content"
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
            minimum: 0
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
                  enum: %w[e p], # TODO: should we allow "unknown" tags?
                  minLength: 1,
                  maxLength: 1
                },
                minLength: 2
              }
            ]
          }
        },
        required: %w[content created_at id kind pubkey sig tags]
      }
    ],
    minItems: 1,
    maxItems: 1
  }.to_json)

  # TODO: refactor later because its completely similar to REQ schema
  # except for `id`
  COUNT_SCHEMA = JSONSchemer.schema({
    "$schema": "http://json-schema.org/draft-07/schema#",
    id: "nostr/nips/01/commands/client/COUNT/",
    type: "array",
    items: [
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
              minLength: 1,
              maxLength: 64
            }
          },
          authors: {
            type: :array,
            id: :authors,
            items: {
              type: :string,
              minLength: 1,
              maxLength: 64
            }
          },
          kinds: {
            type: "array",
            id: "kinds",
            minLength: 1,
            items: {type: "integer", minimum: 0}
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
              minLength: 1,
              maxLength: 64
            }
          },
          "#p": {
            type: :array,
            id: :tagged_pubkeys,
            items: {
              type: :string,
              minLength: 1,
              maxLength: 64
            }
          }
        }
      }
    },
    minItems: 2
    # maxLength: 100 # TODO: set max filters configurable
  }.to_json)
end
