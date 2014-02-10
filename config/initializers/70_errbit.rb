
Airbrake.configure do |config|
  config.api_key = ENV["ERRBIT_API_KEY"]
  config.host    = 'errbit.afterzero.org'
  config.port    = 443
  config.secure  = true
  #config.verify_ssl = false;

  # disable ssl certificate verification for entire application
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE  
end if Rails.env.production?
