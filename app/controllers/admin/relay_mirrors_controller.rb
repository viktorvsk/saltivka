class Admin::RelayMirrorsController < AdminController
  def index
    @relay_mirror = RelayMirror.new
    @relay_mirrors = RelayMirror.all.order("mirror_type, url")
  end

  def create
    @relay_mirror = RelayMirror.new(relay_mirror_params)

    if @relay_mirror.save
      redirect_to admin_relay_mirrors_path, notice: "Relay mirror was successfully updated!"
    else
      @relay_mirrors = RelayMirror.all.order("mirror_type, url")
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    RelayMirror.find(params[:id]).destroy

    redirect_to admin_relay_mirrors_path, notice: "Relay mirror was successfully deleted!"
  end

  def activate
    RelayMirror.where(id: params[:id]).update_all(active: true)

    redirect_to admin_relay_mirrors_path, notice: "Relay mirror was successfully activated!"
  end

  def deactivate
    RelayMirror.where(id: params[:id]).update_all(active: false)

    redirect_to admin_relay_mirrors_path, notice: "Relay mirror was successfully deactivated!"
  end

  private

  def relay_mirror_params
    params.require(:relay_mirror).permit(:url, :active, :mirror_type).merge({
      newest: begin
        Time.parse((1..3).to_a.map { |i| params[:relay_mirror]["newest(#{i}i)"] }.join("-")).to_i
      rescue
        Time.now.to_i
      end,
      oldest: begin
        Time.parse((1..3).to_a.map { |i| params[:relay_mirror]["oldest(#{i}i)"] }.join("-")).to_i
      rescue
        0
      end
    })
  end
end
