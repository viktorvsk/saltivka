require "rails_helper"

RSpec.describe("NIP-42") do
  describe NewEvent do
    context "given a valid event of kind 22242" do
      it "authenticates pubkey" do
        REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])

        expect(MemStore).to receive(:authenticate!).with(cid: "CONN_ID", event_sha256: event.sha256, pubkey: event.pubkey)

        subject.perform("CONN_ID", event.to_json)
      end

      it "adds Sidekiq job to Authorize Request" do
        REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
        nostr_queue = Sidekiq::Queue.new("nostr.nip42")

        expect(MemStore).to receive(:authenticate!).with(cid: "CONN_ID", event_sha256: event.sha256, pubkey: event.pubkey).and_call_original
        expect(nostr_queue.size).to be_zero

        subject.perform("CONN_ID", event.to_json)
        expect(nostr_queue.size).to eq(1)
        expect(nostr_queue.first.args).to eq(["CONN_ID", event.sha256, event.pubkey])
        expect(nostr_queue.first.klass).to eq("AuthorizationRequest")
      end

      it "authenticates pubkey if already authenticated" do
        REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
        REDIS_TEST_CONNECTION.hset("authentications", "CONN_ID", event.pubkey)

        expect(MemStore).to receive(:authenticate!).with(cid: "CONN_ID", event_sha256: event.sha256, pubkey: event.pubkey)

        subject.perform("CONN_ID", event.to_json)
      end

      it "does not authenticate pubkey if already authenticated and config restricts it" do
        REDIS_TEST_CONNECTION.sadd("connections", "CONN_ID")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "CONN_ID"]])
        REDIS_TEST_CONNECTION.hset("authentications", "CONN_ID", event.pubkey)

        allow(RELAY_CONFIG).to receive(:restrict_change_auth_pubkey).and_return(true)
        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :notice, payload: "This connection is already authenticated. To authenticate another pubkey please open new connection")

        subject.perform("CONN_ID", event.to_json)
      end
    end
  end

  describe Event do
    it "fails to persist with valid data since it has an ephemeral kind" do
      REDIS_TEST_CONNECTION.sadd("connections", "secret")
      event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 10.seconds.ago)
      expect(event).to be_valid
      expect(event.save).to be_falsey
      expect(event.errors[:kind]).to include("must not be ephemeral")
    end

    describe "With invalid data" do
      it "requires relay-tag host to match" do
        event = build(:event, kind: 22242, tags: [["relay", "http://invalid"], ["challenge", "secret"]], created_at: 10.seconds.ago)
        expect(event.save).to be_falsey
        expect(event.errors[:tags]).to include("'relay' must equal to ws://localhost:3000")
      end

      it "requires challenge-tag to be present" do
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"]], created_at: 10.seconds.ago)
        expect(event.save).to be_falsey
        expect(event.errors[:tags]).to include("'challenge' is missing")
      end

      it "requires challenge-tag to match one in the database" do
        REDIS_TEST_CONNECTION.sadd("connections", "secret")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "invalid"]], created_at: 10.seconds.ago)
        expect(event.save).to be_falsey
        expect(event.errors[:tags]).to include("'challenge' is invalid")
      end

      it "requires created_at to not be too far in the past" do
        REDIS_TEST_CONNECTION.sadd("connections", "secret")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 1.year.ago)
        expect(event.save).to be_falsey
        expect(event.errors[:created_at]).to include("is too old, must be within 600 seconds")
      end

      it "requires created_at to not be in the future" do
        REDIS_TEST_CONNECTION.sadd("connections", "secret")
        event = build(:event, kind: 22242, tags: [["relay", "http://localhost"], ["challenge", "secret"]], created_at: 10.seconds.from_now)
        expect(event.save).to be_falsey
        expect(event.errors[:created_at]).to include("must not be in the future")
      end
    end
  end

  describe AuthorizationRequest do
    let(:event) { create(:event, author: create(:author, pubkey: FAKE_CREDENTIALS[:alice][:pk])) }
    context "when pubkey is trusted" do
      it "authorizes with level 4" do
        create(:trusted_author, author: event.author)
        expect { subject.perform("CONN_ID", event.sha256, event.pubkey) }.to change { REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID") }.by(1)
        expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("4")
      end
    end

    context "when pubkey is unknown" do
      it "authorizes with level 0" do
        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, false, "restricted: unknown author"].to_json)
        expect { subject.perform("CONN_ID", event.sha256, event.pubkey) }.to change { REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID") }.by(1)
        expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("1")
      end
    end

    context "when pubkey has active subscription" do
      it "authorizes with level 4" do
        create(:author_subscription, :active, author: event.author)
        expect { subject.perform("CONN_ID", event.sha256, event.pubkey) }.to change { REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID") }.by(1)
        expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("3")
      end
    end

    context "when pubkey has inactive subscription" do
      it "authorizes with level 4" do
        create(:author_subscription, author: event.author)
        expect { subject.perform("CONN_ID", event.sha256, event.pubkey) }.to change { REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID") }.by(1)
        expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("1")
      end
    end

    context "with active user" do
      let(:user) { create(:user) }

      context "having multiple pubkeys connected" do
        let!(:inactive_user_pubkey_1) { create(:user_pubkey, user: user) }
        let!(:inactive_user_pubkey_2) { create(:user_pubkey, user: user) }

        context "when one of the pubkeys is active" do
          let!(:active_user_pubkey) do
            pk = create(:user_pubkey, user: user, author: event.author)
            create(:author_subscription, :active, author: event.author)
            pk
          end

          it "authorizes active pubkey with level 3" do
            expect { subject.perform("CONN_ID", event.sha256, event.pubkey) }.to change { REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID") }.by(1)
            expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("3")
          end

          it "authorizes inactive pubkey with level 3" do
            author = create(:author, pubkey: FAKE_CREDENTIALS[:bob][:pk])
            create(:user_pubkey, user: user, author: author)
            event1 = create(:event, author: author)

            expect { subject.perform("CONN_ID", event1.sha256, event1.pubkey) }.to change { REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID") }.by(1)
            expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("3")
          end
        end

        it "authorizes active pubkey with level 2" do
          create(:user_pubkey, user: user, author: event.author)
          expect { subject.perform("CONN_ID", event.sha256, event.pubkey) }.to change { REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID") }.by(1)
          expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("2")
        end
      end
    end

    context "when active User has many connected pubkey" do
      it "authorizes with level 3" do
        user = create(:user)
        create(:user_pubkey, author: event.author, user: user)
        create(:author_subscription, :active, author: event.author)
        expect { subject.perform("CONN_ID", event.sha256, event.pubkey) }.to change { REDIS_TEST_CONNECTION.llen("authorization_result:CONN_ID") }.by(1)
        expect(REDIS_TEST_CONNECTION.lpop("authorization_result:CONN_ID")).to eq("3")
      end
    end
  end

  describe Nostr::AuthenticationFlow do
    it "AUTHs connection_id" do
      expect(subject.call(ws_url: "ws://localhost", connection_id: "CONN_ID") { |message| message }).to eq(["AUTH", "CONN_ID"])
    end
  end
end
