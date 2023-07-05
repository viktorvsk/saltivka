# create User from ENV

if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present? && !User.exists?
  User.create!(email: ENV["ADMIN_EMAIL"], password: ENV["ADMIN_PASSWORD"], password_confirmation: ENV["ADMIN_PASSWORD"])
end

if ENV["TRUSTED_PUBKEYS"].present? && !Author.exists?
  Author.transaction do
    ENV["TRUSTED_PUBKEYS"].split(" ").each do |pk|
      author = Author.new(pubkey: pk)
      author.build_trusted_author
      author.save!
    end
  end
end
