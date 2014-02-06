class CcbConfig < ActiveRecord::Base
  attr_encrypted :api_user
  attr_encrypted :api_password
end
