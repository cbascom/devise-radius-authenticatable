require 'radiustar'
require 'devise/strategies/radius_authenticatable'

module Devise
  module Models
    # The RadiusAuthenticatable module is responsible for validating a user's credentials
    # against the configured radius server.  When authentication is successful, the
    # attributes returned by the radius server are made available via the
    # +radius_attributes+ accessor in the user model.
    #
    # The RadiusAuthenticatable module works by using the configured
    # +radius_uid_generator+ to generate a UID based on the username and the radius server
    # hostname or IP address.  This UID is used to see if an existing record representing
    # the user already exists.  If it does, radius authentication proceeds through that
    # user record.  Otherwise, a new user record is built and authentication proceeds.
    # If authentication is successful, the +after_radius_authentication+ callback is
    # invoked, the default implementation of which simply saves the user record with
    # validations disabled.
    #
    # The radius username is extracted from the parameters hash by using the first
    # configured value in the +Devise.authentication_keys+ array.  If the authentication
    # key is in the list of case insensitive keys, the username will be converted to
    # lowercase prior to authentication.
    #
    # == Options
    #
    # RadiusAuthenticable adds the following options to devise_for:
    # * +radius_server+: The hostname or IP address of the radius server.
    # * +radius_server_port+: The port the radius server is listening on.
    # * +radius_server_secret+: The shared secret configured on the radius server.
    # * +radius_server_timeout+: The number of seconds to wait for a response from the
    #   radius server.
    # * +radius_server_retries+: The number of times to retry a request to the radius
    #   server.
    # * +radius_uid_field+: The database column to store the UID in
    # * +radius_uid_generator+: A proc that takes the username and server as parameters
    #   and returns a string representing the UID
    # * +radius_dictionary_path+: The path containing the radius dictionary files to load
    # * +handle_radius_timeout_as_failure+: Option to handle radius timeout as authentication failure
    #
    # == Callbacks
    #
    # The +after_radius_authentication+ callback is invoked on the user record when
    # radius authentication succeeds for that user but prior to Devise checking if the
    # user is active for authentication.  Its default implementation simply saves the
    # user record with validations disabled.  This method should be overriden if further
    # actions should be taken to make the user valid or active for authentication.  If
    # you override it, be sure to either call super to save the record or to save the
    # record yourself.
    module RadiusAuthenticatable
      extend ActiveSupport::Concern

      included do
        attr_accessor :radius_attributes
      end

      # Use the currently configured radius server to attempt to authenticate the
      # supplied username and password.  If authentication succeeds, make the radius
      # attributes returned by the server available via the radius_attributes accessor.
      # Returns true if authentication was successful and false otherwise.
      #
      # Parameters::
      # * +username+: The username to send to the radius server
      # * +password+: The password to send to the radius server
      def valid_radius_password?(username, password)
        server = self.class.radius_server
        port = self.class.radius_server_port
        secret = self.class.radius_server_secret
        options = {
          :reply_timeout => self.class.radius_server_timeout,
          :retries_number => self.class.radius_server_retries
        }
        if self.class.radius_dictionary_path
          options[:dict] = Radiustar::Dictionary.new(self.class.radius_dictionary_path)
        end

        req = Radiustar::Request.new("#{server}:#{port}", options)

        begin # radiustar #authenticate can throw "Timed out waiting for response packet from server"
          reply = req.authenticate(username, password, secret)
        rescue
          return false if self.class.handle_radius_timeout_as_failure
          raise
        end

        if reply[:code] == 'Access-Accept'
          reply.extract!(:code)
          self.radius_attributes = reply
          true
        else
          false
        end
      end

      # Callback invoked by the RadiusAuthenticatable strategy after authentication
      # with the radius server has succeeded and devise has indicated the model is valid.
      # This callback is invoked prior to devise checking if the model is active for
      # authentication.
      def after_radius_authentication
        self.save(:validate => false)
      end

      module ClassMethods

        Devise::Models.config(self, :radius_server, :radius_server_port,
                              :radius_server_secret, :radius_server_timeout,
                              :radius_server_retries, :radius_uid_field,
                              :radius_uid_generator, :radius_dictionary_path,
                              :handle_radius_timeout_as_failure)

        # Invoked by the RadiusAuthenticatable stratgey to perform the authentication
        # against the radius server.  The username is extracted from the authentication
        # hash and a UID is generated from the username and server IP.  We then search
        # for an existing resource using the UID and configured UID field.  If no resource
        # is found, a new resource is built (not created).  If authentication is
        # successful the callback is responsible for saving the resource.  Returns the
        # resource if authentication succeeds and nil if it does not.
        def find_for_radius_authentication(authentication_hash)
          uid_field = self.radius_uid_field.to_sym
          username, password = radius_credentials(authentication_hash)
          uid = self.radius_uid_generator.call(username, self.radius_server)

          resource = find_for_authentication({ uid_field => uid }) ||
            new(uid_field => uid)

          resource.valid_radius_password?(username, password) ? resource : nil
        end

        # Extract the username and password from the supplied authentication hash.  The
        # username is extracted using the first value from +Devise.authentication_keys+.
        # The username is converted to lowercase if the authentication key is in the list
        # of case insensitive keys configured for Devise.
        def radius_credentials(authentication_hash)
          key = self.authentication_keys.first
          value = authentication_hash[key]
          value.downcase! if (self.case_insensitive_keys || []).include?(key)

          [value, authentication_hash[:password]]
        end
      end
    end
  end
end
