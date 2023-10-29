FactoryBot.define do
  factory :searchable_content do
    event
    language { %w[simple english].sample }

    after(:build) do |event|
      event.tsv_content = "Content"
    end
  end
end
