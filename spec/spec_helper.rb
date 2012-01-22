ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'capybara/rspec'

Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  config.mock_with :rspec

  config.include Mongoid::Matchers
  config.include Devise::TestHelpers, type: :controller
  config.extend ControllerMacros, type: :controller

  config.before(:each) do
    Mongoid::IdentityMap.clear
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  Fog.mock!
end

def basic_auth(username, password)
  @request.env["HTTP_AUTHORIZATION"] = "Basic " + Base64::encode64("#{username}:#{password}")
end
