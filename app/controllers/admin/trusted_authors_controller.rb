class Admin::TrustedAuthorsController < AdminController
  def index
    @pagy, @trusted_authors = pagy(TrustedAuthor.includes(:author).order(created_at: :desc))
  end

  def destroy
    TrustedAuthor.find(params[:id]).destroy
    redirect_to admin_trusted_authors_path, notice: "Deleted successfully"
  end

  def create
    author = Author.create_or_find_by(pubkey: params[:trusted_author][:pubkey])
    TrustedAuthor.create(author: author)
    redirect_to admin_trusted_authors_path, notice: "Created successfully"
  end
end
