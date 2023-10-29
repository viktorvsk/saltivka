SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: author_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.author_subscriptions (
    id bigint NOT NULL,
    author_id bigint NOT NULL,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: author_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.author_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: author_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.author_subscriptions_id_seq OWNED BY public.author_subscriptions.id;


--
-- Name: authors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.authors (
    id bigint NOT NULL,
    pubkey text NOT NULL
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='1000', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='1000');


--
-- Name: authors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.authors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: authors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.authors_id_seq OWNED BY public.authors.id;


--
-- Name: delete_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delete_events (
    sha256 public.citext NOT NULL,
    author_id bigint NOT NULL
);


--
-- Name: event_delegators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_delegators (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    author_id bigint NOT NULL
);


--
-- Name: event_delegators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_delegators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_delegators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_delegators_id_seq OWNED BY public.event_delegators.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id bigint NOT NULL,
    kind integer NOT NULL,
    tags jsonb DEFAULT '[]'::jsonb,
    content bytea,
    author_id bigint NOT NULL,
    sha256 text NOT NULL,
    sig public.citext NOT NULL,
    created_at timestamp(6) without time zone
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='10000', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='10000');


--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invoices (
    id bigint NOT NULL,
    author_id bigint NOT NULL,
    amount_sats integer NOT NULL,
    period_days integer NOT NULL,
    provider public.citext NOT NULL,
    status public.citext DEFAULT 'pending'::character varying NOT NULL,
    external_id character varying,
    order_id public.citext NOT NULL,
    request jsonb DEFAULT '{}'::jsonb,
    response jsonb DEFAULT '{}'::jsonb,
    webhooks jsonb DEFAULT '[]'::jsonb,
    paid_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: invoices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invoices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invoices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invoices_id_seq OWNED BY public.invoices.id;


--
-- Name: relay_mirrors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.relay_mirrors (
    id bigint NOT NULL,
    url character varying NOT NULL,
    active boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    mirror_type character varying,
    oldest integer,
    newest integer,
    session_started_at timestamp(6) without time zone
);


--
-- Name: relay_mirrors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.relay_mirrors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: relay_mirrors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.relay_mirrors_id_seq OWNED BY public.relay_mirrors.id;


--
-- Name: req_filters_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.req_filters_logs (
    id bigint NOT NULL,
    filters jsonb DEFAULT '[]'::jsonb,
    created_at timestamp(6) without time zone
);


--
-- Name: req_filters_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.req_filters_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: req_filters_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.req_filters_logs_id_seq OWNED BY public.req_filters_logs.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: searchable_contents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.searchable_contents (
    event_id bigint NOT NULL,
    language character varying NOT NULL,
    tsv_content tsvector NOT NULL
);


--
-- Name: searchable_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.searchable_tags (
    event_id bigint NOT NULL,
    name character varying NOT NULL,
    value text NOT NULL
)
WITH (autovacuum_vacuum_scale_factor='0.0', autovacuum_vacuum_threshold='10000', autovacuum_analyze_scale_factor='0.0', autovacuum_analyze_threshold='10000');


--
-- Name: trusted_authors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trusted_authors (
    id bigint NOT NULL,
    author_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: trusted_authors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trusted_authors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trusted_authors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trusted_authors_id_seq OWNED BY public.trusted_authors.id;


--
-- Name: user_pubkeys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_pubkeys (
    id bigint NOT NULL,
    author_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    nip05_name public.citext
);


--
-- Name: user_pubkeys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_pubkeys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_pubkeys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_pubkeys_id_seq OWNED BY public.user_pubkeys.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying NOT NULL,
    crypted_password character varying,
    salt character varying,
    admin boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    confirmed_at timestamp(6) without time zone,
    reset_password_token character varying,
    reset_password_token_expires_at timestamp(6) without time zone DEFAULT NULL::timestamp without time zone,
    reset_password_email_sent_at timestamp(6) without time zone DEFAULT NULL::timestamp without time zone,
    access_count_to_reset_password_page integer DEFAULT 0
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: author_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.author_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.author_subscriptions_id_seq'::regclass);


--
-- Name: authors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authors ALTER COLUMN id SET DEFAULT nextval('public.authors_id_seq'::regclass);


--
-- Name: event_delegators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_delegators ALTER COLUMN id SET DEFAULT nextval('public.event_delegators_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: invoices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices ALTER COLUMN id SET DEFAULT nextval('public.invoices_id_seq'::regclass);


--
-- Name: relay_mirrors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relay_mirrors ALTER COLUMN id SET DEFAULT nextval('public.relay_mirrors_id_seq'::regclass);


--
-- Name: req_filters_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.req_filters_logs ALTER COLUMN id SET DEFAULT nextval('public.req_filters_logs_id_seq'::regclass);


--
-- Name: trusted_authors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trusted_authors ALTER COLUMN id SET DEFAULT nextval('public.trusted_authors_id_seq'::regclass);


--
-- Name: user_pubkeys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_pubkeys ALTER COLUMN id SET DEFAULT nextval('public.user_pubkeys_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: author_subscriptions author_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.author_subscriptions
    ADD CONSTRAINT author_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: authors authors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (id);


--
-- Name: event_delegators event_delegators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_delegators
    ADD CONSTRAINT event_delegators_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);


--
-- Name: relay_mirrors relay_mirrors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.relay_mirrors
    ADD CONSTRAINT relay_mirrors_pkey PRIMARY KEY (id);


--
-- Name: req_filters_logs req_filters_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.req_filters_logs
    ADD CONSTRAINT req_filters_logs_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: trusted_authors trusted_authors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trusted_authors
    ADD CONSTRAINT trusted_authors_pkey PRIMARY KEY (id);


--
-- Name: user_pubkeys user_pubkeys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_pubkeys
    ADD CONSTRAINT user_pubkeys_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_author_subscriptions_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_author_subscriptions_on_author_id ON public.author_subscriptions USING btree (author_id);


--
-- Name: index_authors_on_id_and_lower_pubkey; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_authors_on_id_and_lower_pubkey ON public.authors USING btree (id, lower(pubkey));


--
-- Name: index_authors_on_id_include_pubkey; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_authors_on_id_include_pubkey ON public.authors USING btree (id) INCLUDE (pubkey);


--
-- Name: index_authors_on_lower_pubkey; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_authors_on_lower_pubkey ON public.authors USING btree (lower(pubkey));


--
-- Name: index_authors_on_lower_pubkey_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_authors_on_lower_pubkey_and_id ON public.authors USING btree (lower(pubkey), id);


--
-- Name: index_delete_events_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_delete_events_on_author_id ON public.delete_events USING btree (author_id);


--
-- Name: index_delete_events_on_sha256_and_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_delete_events_on_sha256_and_author_id ON public.delete_events USING btree (sha256, author_id);

ALTER TABLE public.delete_events CLUSTER ON index_delete_events_on_sha256_and_author_id;


--
-- Name: index_event_delegators_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_event_delegators_on_event_id ON public.event_delegators USING btree (event_id);


--
-- Name: index_event_delegators_on_event_id_and_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_delegators_on_event_id_and_author_id ON public.event_delegators USING btree (event_id, author_id);

ALTER TABLE public.event_delegators CLUSTER ON index_event_delegators_on_event_id_and_author_id;


--
-- Name: index_events_for_replaceable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_for_replaceable ON public.events USING btree (author_id, created_at, kind) WHERE ((kind = ANY (ARRAY[0, 3, 41])) OR ((kind >= 10000) AND (kind <= 19999)) OR ((kind >= 30000) AND (kind <= 39999)));


--
-- Name: index_events_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_author_id ON public.events USING btree (author_id);


--
-- Name: index_events_on_created_at_and_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_created_at_and_kind ON public.events USING btree (created_at, kind);

ALTER TABLE public.events CLUSTER ON index_events_on_created_at_and_kind;


--
-- Name: index_events_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_id ON public.events USING btree (id) WHERE (jsonb_path_query_array(tags, '$[*][0]'::jsonpath) ? 'expiration'::text);


--
-- Name: index_events_on_kind; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_kind ON public.events USING btree (kind);


--
-- Name: index_events_on_lower_sha256; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_events_on_lower_sha256 ON public.events USING btree (lower(sha256));


--
-- Name: index_invoices_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invoices_on_author_id ON public.invoices USING btree (author_id);


--
-- Name: index_invoices_on_external_id_and_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoices_on_external_id_and_provider ON public.invoices USING btree (external_id, provider);


--
-- Name: index_invoices_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invoices_on_order_id ON public.invoices USING btree (order_id);


--
-- Name: index_relay_mirrors_on_url_and_mirror_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_relay_mirrors_on_url_and_mirror_type ON public.relay_mirrors USING btree (url, mirror_type);


--
-- Name: index_searchable_contents_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_searchable_contents_on_event_id ON public.searchable_contents USING btree (event_id);


--
-- Name: index_searchable_contents_on_tsv_content; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searchable_contents_on_tsv_content ON public.searchable_contents USING gin (tsv_content);


--
-- Name: index_searchable_tags_on_d_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searchable_tags_on_d_tag ON public.searchable_tags USING btree (lower(value), event_id) WHERE ((name)::text = 'd'::text);


--
-- Name: index_searchable_tags_on_e_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searchable_tags_on_e_tag ON public.searchable_tags USING btree (lower(value), event_id) WHERE ((name)::text = 'e'::text);


--
-- Name: index_searchable_tags_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searchable_tags_on_event_id ON public.searchable_tags USING btree (event_id);


--
-- Name: index_searchable_tags_on_event_id_and_name_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_searchable_tags_on_event_id_and_name_and_value ON public.searchable_tags USING btree (event_id, name, lower(value));

ALTER TABLE public.searchable_tags CLUSTER ON index_searchable_tags_on_event_id_and_name_and_value;


--
-- Name: index_searchable_tags_on_other_tags; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searchable_tags_on_other_tags ON public.searchable_tags USING btree (lower(value), event_id) WHERE ((name)::text <> ALL ((ARRAY['e'::character varying, 'p'::character varying])::text[]));


--
-- Name: index_searchable_tags_on_p_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_searchable_tags_on_p_tag ON public.searchable_tags USING btree (lower(value), event_id) WHERE ((name)::text = 'p'::text);


--
-- Name: index_trusted_authors_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_trusted_authors_on_author_id ON public.trusted_authors USING btree (author_id);


--
-- Name: index_user_pubkeys_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_pubkeys_on_author_id ON public.user_pubkeys USING btree (author_id);


--
-- Name: index_user_pubkeys_on_nip05_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_pubkeys_on_nip05_name ON public.user_pubkeys USING btree (nip05_name) WHERE ((nip05_name IS NOT NULL) AND (nip05_name OPERATOR(public.<>) ''::public.citext));


--
-- Name: index_user_pubkeys_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_pubkeys_on_user_id ON public.user_pubkeys USING btree (user_id);


--
-- Name: index_users_on_confirmed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_confirmed_at ON public.users USING btree (confirmed_at);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: searchable_tags fk_rails_0b38f9824a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searchable_tags
    ADD CONSTRAINT fk_rails_0b38f9824a FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: user_pubkeys fk_rails_16b7b84ba8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_pubkeys
    ADD CONSTRAINT fk_rails_16b7b84ba8 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: invoices fk_rails_32fc3ccfac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_rails_32fc3ccfac FOREIGN KEY (author_id) REFERENCES public.authors(id);


--
-- Name: event_delegators fk_rails_3df25f44ef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_delegators
    ADD CONSTRAINT fk_rails_3df25f44ef FOREIGN KEY (author_id) REFERENCES public.authors(id);


--
-- Name: event_delegators fk_rails_5f94d04b9b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_delegators
    ADD CONSTRAINT fk_rails_5f94d04b9b FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: user_pubkeys fk_rails_66431c7d01; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_pubkeys
    ADD CONSTRAINT fk_rails_66431c7d01 FOREIGN KEY (author_id) REFERENCES public.authors(id);


--
-- Name: events fk_rails_7fa7c14967; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_7fa7c14967 FOREIGN KEY (author_id) REFERENCES public.authors(id);


--
-- Name: searchable_contents fk_rails_86c5dd3b26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.searchable_contents
    ADD CONSTRAINT fk_rails_86c5dd3b26 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: delete_events fk_rails_9b916d76a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delete_events
    ADD CONSTRAINT fk_rails_9b916d76a1 FOREIGN KEY (author_id) REFERENCES public.authors(id);


--
-- Name: trusted_authors fk_rails_d1f07d78ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trusted_authors
    ADD CONSTRAINT fk_rails_d1f07d78ea FOREIGN KEY (author_id) REFERENCES public.authors(id);


--
-- Name: author_subscriptions fk_rails_efd00227f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.author_subscriptions
    ADD CONSTRAINT fk_rails_efd00227f9 FOREIGN KEY (author_id) REFERENCES public.authors(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20230604131127'),
('20230608131555'),
('20230621222645'),
('20230624143008'),
('20230703222952'),
('20230705121232'),
('20230708133001'),
('20230710101414'),
('20230711083714'),
('20230714231156'),
('20230715003017'),
('20230720115009'),
('20230722094945'),
('20230722095018'),
('20230722095546'),
('20230726191618'),
('20230727101857'),
('20230727102159'),
('20230727102633'),
('20230728225621'),
('20230728231046'),
('20230728232002'),
('20230728232331'),
('20230729132200'),
('20230731011311'),
('20230731115310'),
('20230801100153'),
('20230801100507'),
('20230802224145'),
('20230804145905'),
('20230819202002'),
('20230826131122'),
('20230826152946'),
('20230826153633'),
('20230827140714'),
('20230827170307'),
('20231025122455');


