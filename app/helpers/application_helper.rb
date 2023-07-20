module ApplicationHelper
  def css_for_flash(flash_type)
    {
      alert: "is-danger",
      notice: "is-success"
    }[flash_type.to_sym]
  end
end
