require 'simplecov'
SimpleCov.start

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'

require 'spec_helper'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'capybara/rspec'
require 'webmock/rspec'

OmniAuth.config.test_mode = true

omniauth_twitter_hash = {
  provider: "twitter",
  uid: "123",
  info: { name: "Greg Tester", nickname: "gtester", :image => 'tester'},
  credentials: { token: "gregtestertoken", secret: "gregtestersecret" }
}

module ActionController::ForceSSL::ClassMethods
  def force_ssl(options = {})
    # noop
  end
end

OmniAuth.config.add_mock(:twitter, omniauth_twitter_hash)

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  config.include ActiveSupport::Testing::TimeHelpers

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!

  config.before(:each) do
    stub_request(:any, /api.twitter.com/).to_rack(FakeTwitter)
  end
end
