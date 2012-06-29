class Radiustar::Request
  def initialize(url, options = {})
    RadiusServer.instance.create_request(url, options)
  end

  def authenticate(username, password, secret)
    RadiusServer.instance.authenticate(username, password)
  end
end

class RadiusServer
  attr_reader :url, :options

  def self.instance
    @@server ||= new
  end

  def initialize
    clear_users
    clear_request
  end

  def create_request(url, options)
    @url = url
    @options = options
  end

  def clear_request
    @url = nil
    @options = nil
  end

  def add_user(username, password, attributes = {})
    @users[username] = {}
    @users[username][:password] = password
    if attributes.empty?
      @users[username][:attributes] = {
      'User-Name' => username,
      'Filter-Id' => 60
    }
    else
      @users[username][:attributes] = attributes
    end
  end

  def clear_users
    @users = {}
  end

  def attributes(username)
    @users[username][:attributes]
  end

  def authenticate(username, password)
    if @users[username][:password] == password
      { :code => 'Access-Accept' }.merge(@users[username][:attributes])
    else
      { :code => 'Access-Reject' }
    end
  end
end

module RadiusHelpers
  def radius_server
    RadiusServer.instance
  end

  def create_radius_user(username, password, attributes = {})
    RadiusServer.instance.add_user(username, password, attributes)
  end

  def clear_radius_users
    RadiusServer.instance.clear_users
  end
end

RSpec::configure do |c|
  c.include RadiusHelpers

  c.after(:each) do
    RadiusServer.instance.clear_request
    RadiusServer.instance.clear_users
  end
end
