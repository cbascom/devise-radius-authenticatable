require 'spec_helper'

describe "login" do
  before do
    @admin = FactoryGirl.create(:admin, :password => 'password')
    create_radius_user('testuser', 'password')
    visit new_admin_session_path
  end

  it "is successful for a database user" do
    fill_in "Login", :with => @admin.email
    fill_in "Password", :with => 'password'
    click_button "Sign in"

    current_path.should == root_path
    page.should have_content("Signed in successfully")
  end

  it "is successful for a radius user" do
    fill_in "Login", :with => 'testuser'
    fill_in "Password", :with => 'password'
    click_button "Sign in"

    current_path.should == root_path
    page.should have_content("Signed in successfully")
  end

  it "fails for wrong database password" do
    fill_in "Login", :with => @admin.email
    fill_in "Password", :with => 'password2'
    click_button "Sign in"

    current_path.should == new_admin_session_path
    page.should have_content("Invalid email or password")
  end

  it "fails for wrong radius password" do
    fill_in "Login", :with => 'testuser'
    fill_in "Password", :with => 'password2'
    click_button "Sign in"

    current_path.should == new_admin_session_path
    page.should have_content("Invalid email or password")
  end

  it "invokes the after_radius_authentication callback" do
    fill_in "Login", :with => 'testuser'
    fill_in "Password", :with => 'password'
    click_button "Sign in"

    uid = Admin.radius_uid_generator.call('testuser', Admin.radius_server)
    Admin.where(Admin.radius_uid_field => uid).count.should == 1
  end

  it "successfully logs in a user with case insensitive username" do
    swap(Devise, :case_insensitive_keys => [Admin.authentication_keys.first]) do
      fill_in "Login", :with => 'TESTUSER'
      fill_in "Password", :with => 'password'
      click_button "Sign in"

      current_path.should == root_path
      page.should have_content("Signed in successfully")
    end
  end

  it "fails to log in a user with case sensitive username" do
    swap(Devise, :case_insensitive_keys => []) do
      fill_in "Login", :with => 'TESTUSER'
      fill_in "Password", :with => 'password'
      click_button "Sign in"

      current_path.should == new_admin_session_path
      page.should have_content("Invalid email or password")
    end
  end

  context "when radius authentication is the first strategy" do
    before do
      @admin2 = FactoryGirl.create(:admin, :password => 'password')
      create_radius_user(@admin2.email, 'password2')

      @orig_order = Devise.warden_config.default_strategies(:scope => :admin)
      Devise.warden_config.default_strategies(:radius_authenticatable,
                                              :database_authenticatable,
                                              {:scope => :admin})
    end

    after do
      Devise.warden_config.default_strategies(@orig_order, {:scope => :admin})
    end

    it "proceeds with the next strategy if radius authentication fails" do
      fill_in "Login", :with => @admin2.email
      fill_in "Password", :with => 'password'
      click_button "Sign in"

      current_path.should == root_path
      page.should have_content("Signed in successfully")
    end
  end
end
