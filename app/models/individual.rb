class Individual < ActiveRecord::Base
  serialize :object_json

  validates :individual_id, presence: true
  validates :family_id, presence: true
  validates :object_json, presence: true
end
