require 'devise'

module Devise
  # The hostname or IP address of the radius server
  mattr_accessor :radius_server

  # The port for the radius server
  mattr_accessor :radius_server_port
  @@radius_server_port = 1812

  # The secret for the radius server
  mattr_accessor :radius_server_secret

  # The timeout in seconds for radius requests
  mattr_accessor :radius_server_timeout
  @@radius_server_timeout = 60

  # The number of times to retry radius requests
  mattr_accessor :radius_server_retries
  @@radius_server_retries = 0

  # The database column that holds the unique identifier for the radius user
  mattr_accessor :radius_uid_field
  @@radius_uid_field = :radius_uid

  # The procedure to use to build the unique identifier for the radius user
  mattr_accessor :radius_uid_generator
  @@radius_uid_generator = Proc.new { |username, server| "#{username}@#{server}" }

  # The path to load radius dictionary files from
  mattr_accessor :radius_dictionary_path
end

Devise.add_module(:radius_authenticatable, :route => :session, :strategy => true,
                  :controller => :sessions, :model  => true)
