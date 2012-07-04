require 'radiustar'
require 'devise/strategies/radius_authenticatable'

module Devise
  module Models
    module RadiusAuthenticatable
      extend ActiveSupport::Concern

      included do
        attr_accessor :radius_attributes
      end

      def valid_radius_password?(username, password)
        server = self.class.radius_server
        port = self.class.radius_server_port
        secret = self.class.radius_server_secret
        options = {
          :reply_timeout => self.class.radius_server_timeout,
          :retries_number => self.class.radius_server_retries
        }

        req = Radiustar::Request.new("#{server}:#{port}", options)
        reply = req.authenticate(username, password, secret)

        if reply[:code] == 'Access-Accept'
          reply.extract!(:code)
          self.radius_attributes = reply
          true
        else
          false
        end
      end

      def after_radius_authentication
        self.save(:validate => false)
      end

      module ClassMethods

        Devise::Models.config(self, :radius_server, :radius_server_port,
                              :radius_server_secret, :radius_server_timeout,
                              :radius_server_retries, :radius_uid_field,
                              :radius_uid_generator)

        def find_for_radius_authentication(authentication_hash)
          uid_field = self.radius_uid_field.to_sym
          username, password = radius_credentials(authentication_hash)
          uid = self.radius_uid_generator.call(username, self.radius_server)

          resource = find_for_authentication({ uid_field => uid }) ||
            new(uid_field => uid)

          resource.valid_radius_password?(username, password) ? resource : nil
        end

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
