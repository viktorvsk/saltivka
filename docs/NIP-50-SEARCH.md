# NIP-50 Search

## Architecture

Saltivka search uses [PostgreSQL full-text search](https://www.postgresql.org/docs/current/textsearch-intro.html#TEXTSEARCH-MATCHING).
It is much more powerful than SQL `%LIKE%` or `regex` based queries.
But much less powerful than dedicated search solutions i.e. Elasticsearch, Solr, Sphinx etc.
Which are in turn much less powerful than something Google or Bing implement under the hood.
All because full text search is a complex (and biased) topic.

Thats why Saltivka doesn't try to offer "best" full text search experience instead
it has optimal soultion — best quality/complexity ratio which presumambly meets
needs of 80% of users. Technically speaking, it enables lexeme-based search using built-in language-specific dictionaries.
It *does not* offer fuzzy matching, misspelling, synonims, vector relevance and context-aware search in particular.

Important thing to notice, NIP-50 search is implemented in the same way as any other NIP-1 filter (`kinds`, `ids`, `authors`, `since`, `until` and single-letter tags i.e. `#t`)
which allows any combination of those and also works for both: stored and new events.
So its possible to search for notes `of your favorite author with a rich-note kind during last week among a (big) list of notes ids`.

Default [parsing query](https://www.postgresql.org/docs/16/textsearch-controls.html#TEXTSEARCH-PARSING-QUERIES) method is `websearch_to_tsquery` unless specified in extensions.

### Indexing

Each time new event is stored in the system, there may be stored an associated
database record in the table `searchable_contents` that will play a role of an index.
There are some rules to how and when this index is built, see Configuration section for details.

### New Events

While PostgreSQL performs search on stored tables, we don't need this in case when
new event is added to the relay and we have to define which subscriptions should
receive it.

In order to avoid unnecessary database interactions and to keep business logic of how
search works expected on new event static SQL query is constructed with events content
and matched against subscriptions with a `#search` filter using actual database server.
However since it does not involve interaction with any records stored in the database, this
action is extremely robust.

### Limitations

* [https://www.postgresql.org/docs/current/textsearch-limitations.html](https://www.postgresql.org/docs/current/textsearch-limitations.html)
* Fuzzy matching, misspelling correction, synonims search, vector relevance and context-aware search are *NOT* supported
* No particular ranking relevance implemented
* Relay indexes all new Events that match certain criteria. However, if in future you decide to index additional kind, it will only be applied to newer Events. To index old events, it has to be done manually. In future there are plans to make this process smoother.
* While spam detection has nothing in common with full text search, NIP-50 mentions spam specifically when describing extensions. No spam extension is implemented right now. It is planned in future to *control* spam inclusion/exclusion using such extension. But it is not planned to actually implement spam filter/detection mechanisms in the relay.

## Extensions

NIP-50 assumes extensions MAY be a part of a query string.

### Mode Extension

`m:<MODE>` — where `<MODE>` is one of: `plain`, `phrase`, `manual`, `prefix` or anything else that will default to `websearch_to_tsquery`

`plain` — uses `plainto_tsquery`

`phrase` — uses `phraseto_tsquery`

`manual` — uses `to_tsquery`

`prefix` — uses `to_tsquery` and modifies text by appending `:*` to each of the words


Example query string `m:prefix Saltivk` will become `SELECT ... FROM ... WHERE tsv_content @@ to_tsquery('saltivk:*')` and would be able to match content with `Saltivka` mention.

Refer to PostgreSQL documentation mentioned above to learn `phraseto_tsquery` and `websearch_to_tsquery` syntax you can use for better search control.


## Configuration

There are 2 configuration options available for NIP-50 search feature.

* `NIP_50_DEFAULT_LANGUAGE=simple`. It controls default config/language to assign for content when Event is indexed. More details [here](https://www.postgresql.org/docs/16/textsearch-dictionaries.html). It is assumed that if you expect your relay to be used by english-speaking community, you set it to `english`. In case of spanish-speaking community to `spanish`. List of options depends on your PostgreSQL deployment. In future API will be added to change language for existing Events, because it is pretty expensive to detect language at the same moment Event is created so we just use default one.
* `NIP_50_CONTENT_SEARCHABLE_KINDS=0 1 30023`. It defines which Event kinds the relay will index. For instance, some event kinds contain encrypted content (kind-4) and have so sense to be indexed. While other Event kinds contain JSON and benefit from some custom pre-processing (i.e. kind-0). Basically, any kind could be added and indexed, the only matter is search relevance.
