if Rails.env.production?
  DelayedJobWeb.use Rack::Auth::Basic do |username, password|
    username == ENV['delayed_job_web_username'] && password == ENV['delayed_job_web_password']
  end
end
