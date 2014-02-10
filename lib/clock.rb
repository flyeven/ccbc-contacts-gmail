require 'clockwork'
require './config/boot'
require './config/environment'

module Clockwork

  Clockwork.configure do |config|
    config[:sleep_timeout] = 60 # seconds
  end

  every(1.day, 'Update Contacts', at: '01:00') { Importer.delay.run_recurring_updates }

end
