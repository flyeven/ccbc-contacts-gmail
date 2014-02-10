# # see http://stackoverflow.com/questions/11199553/where-to-define-rails-apps-version-number
# class Configuration
#   class << self
#     attr_reader :app_version, :app_name
#   end
#   @app_version = "1.0.0"
#   @app_name = "ccbc-contacts-gmail"
# end

VERSION="1.0.0"
APP_NAME="ccbc-contacts-gmail"

# http://stackoverflow.com/questions/1047943/best-way-to-version-a-rails-app/6178378#6178378
APP_VERSION=`git describe --always --tags` unless defined? APP_VERSION
