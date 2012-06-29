class Admin < ActiveRecord::Base
  devise :database_authenticatable, :token_authenticatable, :radius_authenticatable

  attr_accessor :login

  attr_accessible :login, :email, :password, :password_confirmation, :remember_me, :uid

  def self.find_for_database_authentication(conditions)
    login = conditions.delete(:login)
    conditions[:email] = login
    super
  end
end
