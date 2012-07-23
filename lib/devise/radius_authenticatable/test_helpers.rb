require 'singleton'

module Devise
  module RadiusAuthenticatable
    # The Devise::RadiusAuthenticatable::TestHelpers module provides a very simple stub
    # server through the RadiusServer class.  It modifies the Radiustar::Request.new
    # method to create a request in the stub server that can be used to check that the
    # proper information is passed to the radius server.  It also modifies the
    # Radiustar::Request#authenticate method to perform authentication against the stub
    # server.
    #
    # The RadiusServer class offers a simple interface for creating users prior to your
    # tests.  The create_radius_user method allows for the creation of a radius user
    # within the stub server.  The radius_server method provides the RadiusServer instance
    # that test assertions can be performed against.
    #
    # The stub server is a singleton class to provide easy access.  This means that it
    # needs to have all state cleared out between tests.  The clear_radius_users and
    # clear_radius_request methods offer an easy way to clear the user and request info
    # out of the server between tests.
    module TestHelpers
      def radius_server
        RadiusServer.instance
      end

      def create_radius_user(username, password, attributes = {})
        RadiusServer.instance.add_user(username, password, attributes)
      end

      def clear_radius_users
        RadiusServer.instance.clear_users
      end

      def clear_radius_request
        RadiusServer.instance.clear_request
      end

      # Stub RadiusServer that allows testing of radius authentication without a real
      # server.
      class RadiusServer
        include Singleton

        attr_reader :url, :options

        def initialize
          clear_users
          clear_request
        end

        # Stores the information about the radius request that would have been sent to
        # the radius server.  This information can be queried to determine that the
        # proper information is being sent.
        def create_request(url, options)
          @url = url
          @options = options
        end

        # Clear the request information that is stored.
        def clear_request
          @url = nil
          @options = nil
        end

        # Add a user to the radius server to use for authentication purposes.  A couple
        # of default attributes will be returned in the auth response if no attributes
        # are supplied when creating the user.
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

        # Clear the users that have been configured for the radius server.
        def clear_users
          @users = {}
        end

        # Accessor to retrieve the attributes configured for the specified user.
        def attributes(username)
          @users[username][:attributes]
        end

        # Called to perform authentication using the specified username and password.  If
        # the authentication is successful, an Access-Accept is returned along with the
        # radius attributes configured for the user.  If authentication fails, an
        # Access-Reject is returned.
        def authenticate(username, password)
          if @users[username] && @users[username][:password] == password
            { :code => 'Access-Accept' }.merge(@users[username][:attributes])
          else
            { :code => 'Access-Reject' }
          end
        end
      end

      def self.included(mod)
        Radiustar::Request.class_eval do
          def initialize(url, options = {})
            Devise::RadiusAuthenticatable::TestHelpers::RadiusServer.instance.
              create_request(url, options)
          end

          def authenticate(username, password, secret)
            Devise::RadiusAuthenticatable::TestHelpers::RadiusServer.instance.
              authenticate(username, password)
          end
        end

        if mod.respond_to?(:after)
          mod.after(:each) do
            Devise::RadiusAuthenticatable::TestHelpers::RadiusServer.instance.
              clear_request
            Devise::RadiusAuthenticatable::TestHelpers::RadiusServer.instance.clear_users
          end
        end
      end
    end
  end
end
