class User < ActiveRecord::Base

  serialize :authorization
  serialize :options

  before_create :hash_field

  def hash_field
    self.md5 = Digest::MD5.hexdigest(self.email)
  end

end
