source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4'

# Use sqlite3 as the database for Active Record
gem 'sqlite3'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
# gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 1.2'

gem 'bootstrap-sass'
gem 'font-awesome-sass', '4.0.2'

group :doc do
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', require: false
end

# Use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.1.2'

# Use unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano', group: :development

# Use debugger
# gem 'debugger', group: [:development, :test]

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'capistrano', '~> 3.2'
  gem 'capistrano-rails'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'
  gem 'capistrano-passenger'
  gem 'quiet_assets'
  gem 'rails_layout'
  gem 'thin'
end

gem 'google-api-client'

#dev
#gem 'church-community-builder', :require => 'ccb_api', path: '../church-community-builder-api-ruby'
gem 'church-community-builder', :require => 'ccb_api', git: 'https://github.com/mfrederickson/church-community-builder-api-ruby'
#gem 'google-contacts', path: '../google-contacts'
gem 'google-contacts', git: 'https://github.com/mfrederickson/google-contacts'

gem 'attr_encrypted'
gem 'figaro'

# Process jobs in the background
gem 'foreman', :group => :development
gem 'delayed_job_active_record'
gem 'clockwork'

gem 'mysql2'
gem 'daemons'
gem 'airbrake'

gem 'sprockets', '2.10.1'
