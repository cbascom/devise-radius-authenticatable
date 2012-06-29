require 'spec_helper'

class Configurable < Admin
  devise(:radius_authenticatable, :radius_server => '1.2.3.4',
         :radius_server_port => 1813, :radius_server_secret => 'secret',
         :radius_server_timeout => 120, :radius_server_retries => 3,
         :radius_uid_field => :email,
         :radius_uid_generator => Proc.new { |username, server|
           "#{username}_#{server}"
         })
end

describe Devise::Models::RadiusAuthenticatable do
  include DeviseHelpers

  let(:auth_key) { Devise.authentication_keys.first }

  it "allows configuration of the radius server IP" do
    Configurable.radius_server.should == '1.2.3.4'
  end

  it "allows configuration of the radius server port" do
    Configurable.radius_server_port.should == 1813
  end

  it "allows configuration of the radius server shared secret" do
    Configurable.radius_server_secret.should == 'secret'
  end

  it "allows configuration of the radius server timeout" do
    Configurable.radius_server_timeout.should == 120
  end

  it "allows configuration of the radius server retries" do
    Configurable.radius_server_retries.should == 3
  end

  it "allows configuration of the radius uid field" do
    Configurable.radius_uid_field.should == :email
  end

  it "allows configuration of the radius uid generator" do
    Configurable.radius_uid_generator.call('test', '1.2.3.4').should == 'test_1.2.3.4'
  end

  it "extracts radius credentials based on the configured authentication keys" do
    swap(Devise, :authentication_keys => [:username, :domain]) do
      auth_hash = { :username => 'cbascom', :password => 'testing' }
      Configurable.radius_credentials(auth_hash).should == ['cbascom', 'testing']
    end
  end

  context "when finding the user record for authentication" do
    let(:good_auth_hash) { {auth_key => 'testuser', :password => 'password'} }
    let(:bad_auth_hash) { {auth_key => 'testuser', :password => 'wrongpassword'} }

    before do
      @uid_field = Admin.radius_uid_field.to_sym
      @uid = Admin.radius_uid_generator.call('testuser', Admin.radius_server)
      create_radius_user('testuser', 'password')
    end

    it "uses the generated uid and configured uid field to find the record" do
      Admin.should_receive(:find_for_authentication).with(@uid_field => @uid)
      Admin.find_for_radius_authentication(good_auth_hash)
    end

    context "and authentication succeeds" do
      it "creates a new user record if none was found" do
        Admin.find_for_radius_authentication(good_auth_hash)
        Admin.where(@uid_field => @uid).count.should == 1
      end

      it "uses the existing user record when one is found" do
        admin = FactoryGirl.create(:admin, @uid_field => @uid)
        Admin.find_for_radius_authentication(good_auth_hash).should == admin
      end

      it "invokes the radius_authentication_succeeded callback" do
        Admin.any_instance.should_receive(:radius_authentication_succeeded)
        Admin.find_for_radius_authentication(good_auth_hash)
      end

      it "returns the user record" do
        admin = Admin.find_for_radius_authentication(good_auth_hash)
        admin.should be_an_instance_of(Admin)
      end
    end

    context "and authentication fails" do
      it "does not create a new user record" do
        Admin.find_for_radius_authentication(bad_auth_hash)
        Admin.where(@uid_field => @uid).count.should == 0
      end

      it "does not invoke the radius_authentication_succeeded callback" do
        Admin.any_instance.should_not_receive(:radius_authentication_succeeded)
        Admin.find_for_radius_authentication(bad_auth_hash)
      end

      it "returns nil" do
        admin = Admin.find_for_radius_authentication(bad_auth_hash)
        admin.should be_nil
      end
    end
  end

  context "when validating a radius user's password" do
    before do
      @admin = Admin.new
      create_radius_user('testuser', 'password')
    end

    it "passes the configured options when building the radius request" do
      server_url = "#{Admin.radius_server}:#{Admin.radius_server_port}"
      server_options = {
        :reply_timeout => Admin.radius_server_timeout,
        :retries_number => Admin.radius_server_retries
      }
      @admin.valid_radius_password?('testuser', 'password')

      radius_server.url.should == server_url
      radius_server.options.should == server_options
    end

    it "returns false when the password is incorrect" do
      @admin.valid_radius_password?('testuser', 'wrongpassword').should be_false
    end

    it "returns true when the password is correct" do
      @admin.valid_radius_password?('testuser', 'password').should be_true
    end

    it "stores the returned attributes in the model" do
      @admin.valid_radius_password?('testuser', 'password')
      @admin.radius_attributes.should == radius_server.attributes('testuser')
    end
  end
end
