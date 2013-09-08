require 'spec_helper'
require 'generators/devise_radius_authenticatable/install_generator'

describe DeviseRadiusAuthenticatable::InstallGenerator do
  destination File.expand_path("../../../tmp", __FILE__)

  before do
    prepare_devise
  end

  it "requires the radius server IP to be specified" do
    expect { run_generator }.
      to raise_error(Thor::RequiredArgumentMissingError,
                     /required arguments 'server'/)
  end

  it "requires the radius server shared secret to be specified" do
    expect { run_generator ['1.1.1.1'] }.
      to raise_error(Thor::RequiredArgumentMissingError,
                     /required arguments 'secret'/)
  end

  context "with required arguments" do

    subject { file('config/initializers/devise.rb') }

    context "with default options" do
      before do
        run_generator ['1.1.1.1', 'secret']
      end

      it { should exist }
      it { should contain('==> Configuration for radius_authenticatable') }
      it { should contain("config.radius_server = '1.1.1.1'") }
      it { should contain("config.radius_server_port = 1812") }
      it { should contain("config.radius_server_secret = 'secret'") }
      it { should contain("config.radius_server_timeout = 60") }
      it { should contain("config.radius_server_retries = 0") }
      it { should contain("config.radius_uid_field = :uid") }
      it { should contain("config.radius_uid_generator =") }
      it { should contain("config.radius_dictionary_path =") }
      it { should contain("config.handle_radius_timeout_as_failure = false") }
    end

    context "with custom options" do
      before do
        run_generator ['1.1.1.2', 'password', '--port=1813',
          '--timeout=120', '--retries=3', '--uid_field=email',
          '--dictionary_path=/tmp/dictionaries',
          '--handle_timeout_as_failure=true']
      end

      it { should exist }
      it { should contain('==> Configuration for radius_authenticatable') }
      it { should contain("config.radius_server = '1.1.1.2'") }
      it { should contain("config.radius_server_port = 1813") }
      it { should contain("config.radius_server_secret = 'password'") }
      it { should contain("config.radius_server_timeout = 120") }
      it { should contain("config.radius_server_retries = 3") }
      it { should contain("config.radius_uid_field = :email") }
      it { should contain("config.radius_uid_generator =") }
      it { should contain("config.radius_dictionary_path = '/tmp/dictionaries'") }
      it { should contain("config.handle_radius_timeout_as_failure = true") }
    end
  end
end
