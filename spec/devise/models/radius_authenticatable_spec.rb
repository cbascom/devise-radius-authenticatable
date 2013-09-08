require 'spec_helper'

class Configurable < Admin
  devise(:radius_authenticatable, :radius_server => '1.2.3.4',
         :radius_server_port => 1813, :radius_server_secret => 'secret',
         :radius_server_timeout => 120, :radius_server_retries => 3,
         :radius_uid_field => :email,
         :radius_uid_generator => Proc.new { |username, server|
           "#{username}_#{server}"
         },
         :radius_dictionary_path => Rails.root.join('config/dictionaries'),
         :handle_radius_timeout_as_failure => true)
end

describe Devise::Models::RadiusAuthenticatable do
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

  it "allows configuration of the radius dictionary path" do
    Configurable.radius_dictionary_path.should == Rails.root.join('config/dictionaries')
  end

  it "allows configuration of the radius exception handling" do
    Configurable.handle_radius_timeout_as_failure.should == true
  end

  it "extracts radius credentials based on the configured authentication keys" do
    swap(Devise, :authentication_keys => [:username, :domain]) do
      auth_hash = { :username => 'cbascom', :password => 'testing' }
      Configurable.radius_credentials(auth_hash).should == ['cbascom', 'testing']
    end
  end

  it "converts the username to lower case if the key is case insensitive" do
    swap(Devise, {:authentication_keys => [:username, :domain],
           :case_insensitive_keys => [:username]}) do
      auth_hash = { :username => 'Cbascom', :password => 'testing' }
      Configurable.radius_credentials(auth_hash).should == ['cbascom', 'testing']
    end
  end

  it "does not convert the username to lower case if the key is not case insensitive" do
    swap(Devise, {:authentication_keys => [:username, :domain],
           :case_insensitive_keys => []}) do
      auth_hash = { :username => 'Cbascom', :password => 'testing' }
      Configurable.radius_credentials(auth_hash).should == ['Cbascom', 'testing']
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
        Admin.find_for_radius_authentication(good_auth_hash).should be_new_record
      end

      it "fills in the uid when creating the new record" do
        admin = Admin.find_for_radius_authentication(good_auth_hash)
        admin.send(@uid_field).should == @uid
      end

      it "uses the existing user record when one is found" do
        admin = FactoryGirl.create(:admin, @uid_field => @uid)
        Admin.find_for_radius_authentication(good_auth_hash).should == admin
      end
    end

    context "and authentication fails" do
      it "does not create a new user record" do
        Admin.find_for_radius_authentication(bad_auth_hash).should be_nil
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
      @admin.valid_radius_password?('testuser', 'password')

      radius_server.url.should == server_url
      radius_server.options[:reply_timeout].should == Admin.radius_server_timeout
      radius_server.options[:retries_number].should == Admin.radius_server_retries
      radius_server.options[:dict].should be_a(Radiustar::Dictionary)
    end

    it "does not add the :dict option if no dictionary path is configured" do
      swap(Admin, :radius_dictionary_path => nil) do
        @admin.valid_radius_password?('testuser', 'password')
        radius_server.options.should_not have_key(:dict)
      end
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

    context "when handle_radius_timeout_as_failure is false" do
      it "does not catch the RuntimeError exception" do
        Radiustar::Request.any_instance.stub(:authenticate).
          and_raise(RuntimeError)
        expect { @admin.valid_radius_password?('testuser', 'password') }.
          to raise_error(RuntimeError)
      end
    end

    context "when handle_radius_timeout_as_failure is true" do
      it "returns false when the authentication times out" do
        swap(Devise, :handle_radius_timeout_as_failure => true) do
          Radiustar::Request.any_instance.stub(:authenticate).
            and_raise(RuntimeError)
          @admin.valid_radius_password?('testuser', 'password').should be_false
        end
      end
    end
  end
end
