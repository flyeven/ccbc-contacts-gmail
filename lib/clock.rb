require 'clockwork'

require './config/boot'
require './config/environment'

module Clockwork

  Clockwork.configure do |config|
    config[:sleep_timeout] = 60 # seconds
  end

  every(1.day, 'Update Contacts', at: '00:00') do
    #DynamicContent.delay.refresh
    Users.where(recurring: true).each do |user|
      begin
        Importer.perform_import(user)
      rescue => e
        Rails.logger.error("scheduled import for #{user.name} failed.")
        Rails.logger.error(e.message)
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end

end
