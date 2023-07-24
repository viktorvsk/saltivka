require "rails_helper"

RSpec.describe("NIP-13") do
  describe NewEvent do
    context "with big PoW difficulty config" do
      before { allow(RELAY_CONFIG).to receive(:min_pow).and_return(1000) }
      it "does not fanout" do
        event = build(:event, kind: 1, created_at: 1.day.ago)
        expect(MemStore).to receive(:fanout).with(cid: "CONN_ID", command: :ok, payload: ["OK", event.sha256, false, "pow: min difficulty must be 1000, got #{event.pow_difficulty}"].to_json)
        subject.perform("CONN_ID", event.to_json)
      end
    end
  end

  describe Event do
    let(:event_without_pow) do
      sk = "945e01e37662430162121b804d3645a86d97df9d256917d86735d0eb219393eb"
      pk = "a19f19f63dc65c8053c9aa332a5d1721a9b522b8cb4a6342582e7f8c4c2d6b95"
      sha256 = "bf84a73d1e6a1708b1c4dc5555a78f342ef29abfd469a091ca4f34533399c95f"

      ctx = Secp256k1::Context.new
      key_pair = ctx.key_pair_from_private_key([sk].pack("H*"))
      sig = ctx.sign_schnorr(key_pair, [sha256].pack("H*")).serialized.unpack1("H*")

      event_params = {
        created_at: Time.at(1687183979),
        kind: 0,
        tags: [],
        content: "",
        sha256: sha256,
        sig: sig,
        pubkey: pk
      }

      Event.new(event_params)
    end
    let(:event_with_pow) do
      with_pow = JSON.parse(File.read(Rails.root.join("spec", "support", "nostr_event_pow.json")))
      event_with_pow = with_pow.merge({
        "created_at" => Time.at(with_pow["created_at"]),
        "sha256" => with_pow.delete("id"),
        "sig" => with_pow.delete("sig")
      })

      Event.new(event_with_pow)
    end
    it "treats any event as valid" do
      expect(event_with_pow).to be_valid
      expect(event_without_pow).to be_valid
    end

    context "with PoW difficulty set to 1" do
      before { allow(RELAY_CONFIG).to receive(:min_pow).and_return(1) }

      it "only validates events with PoW > 0" do
        expect(event_with_pow).to be_valid
        expect(event_without_pow).to_not be_valid
      end
    end
  end
end
