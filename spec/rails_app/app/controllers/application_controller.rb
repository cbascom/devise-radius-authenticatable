class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :authenticate_admin!

  protected

  def after_sign_out_path_for(resource)
    new_admin_session_path
  end
end
