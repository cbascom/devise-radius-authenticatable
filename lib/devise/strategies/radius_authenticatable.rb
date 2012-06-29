require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class RadiusAuthenticatable < Authenticatable
      def authenticate!
        resource = valid_password? &&
          mapping.to.find_for_radius_authentication(params[scope])
        return fail(:invalid) unless resource

        if validate(resource)
          resource.after_radius_authentication
          success!(resource)
        end
      end
    end
  end
end

Warden::Strategies.add(:radius_authenticatable, Devise::Strategies::RadiusAuthenticatable)
