# load the defaults
# depends on secret_token initializer

CCB_USERNAME = ENV["CCB_USERNAME"]
CCB_PASSWORD = ENV["CCB_PASSWORD"]
CCB_SUBDOMAIN = ENV["CCB_SUBDOMAIN"]

if ActiveRecord::Base.connection.table_exists?('ccb_configs')
  if !CcbConfig.exists?(subdomain: CCB_SUBDOMAIN)
    CcbConfig.create({subdomain: CCB_SUBDOMAIN, api_user: CCB_USERNAME, api_password: CCB_PASSWORD})
  end
end
