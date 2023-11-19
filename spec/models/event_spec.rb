require "rails_helper"

RSpec.describe(Event) do
  let(:kind2_event) { build(:event, kind: 2) }
  let(:auth_event) { build(:event, kind: 22242) }
  let(:unknown_event) { build(:event, kind: 100_000) }

  it "detects kind correctly" do
    assert kind2_event.kinda?(:recommend_server)
    assert kind2_event.kinda?(:protocol_reserved)
    assert auth_event.kinda?(:ephemeral)
    assert auth_event.kinda?(:private)
    assert unknown_event.kinda?(:unknown)
  end

  it "creates event" do
    expect { kind2_event.save }.to change { kind2_event.persisted? }.from(false).to(true)
  end

  it "destroys event" do
    kind2_event.save!
    kind2_event_with_searchable_content_included = Event.includes(:searchable_content).where(id: kind2_event).first
    expect { kind2_event_with_searchable_content_included.destroy }.to change { kind2_event_with_searchable_content_included.persisted? }.from(true).to(false)
  end

  context "raises ActiveRecord::ReadOnlyRecord when" do
    let(:event) { create(:event) }

    it "Event#update" do
      expect { event.update!(kind: 12345) }.to raise_exception(ActiveRecord::RecordInvalid)
    end

    it "Event#update_attribute" do
      expect { event.update_attribute(:kind, 12345) }.to raise_exception(ActiveRecord::ReadOnlyRecord)
    end

    it "Event.update_column" do
      expect { event.update_column(:kind, 12345) }.to raise_exception(ActiveRecord::ReadOnlyRecord)
    end

    # TODO: there is no easy way t override .update_all for a single model
    # https://stackoverflow.com/questions/19076886/override-rails-update-all-method
    # https://gist.github.com/timm-oh/9b702a15f61a5dd20d5814b607dc411d
    # it "Event.update_all" do
    #   expect { Event.where(id: event.id).update_all(kind: 12345) }.to raise_exception(ActiveRecord::ReadOnlyRecord)
    # end

    it "Event#touch" do
      expect { event.touch }.to raise_exception(ActiveRecord::ReadOnlyRecord)
    end
  end
end
