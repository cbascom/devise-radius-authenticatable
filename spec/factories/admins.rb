FactoryGirl.define do
  sequence :admin_email do |n|
    "admin#{n}@gmail.com"
  end

  factory :admin do
    email     { FactoryGirl.generate(:admin_email) }
    password  "password"
  end
end
