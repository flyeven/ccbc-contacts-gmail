# to deploy:
# 1. after you clone the project, make sure that you have your client_secrets.json, 
#    database.yml, and application.yml files in your config directory.
# 2. set up your deploy/destination.rb file.
# 3. run:  cap destination deploy

set :user, "deploy"

set :ssh_options, {
  #verbose: :debug,
  user: fetch(:user)
}

set :application, 'ccbc-contacts-gmail'
set :repo_url, "https://github.com/mfrederickson/ccbc-contacts-gmail.git"

# set :rails_relative_url_root, "/#{fetch(:application)}"

# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# set :deploy_to, '/var/www/my_app'
# set :scm, :git

# set :format, :pretty
set :log_level, :info
set :pty, true

set :linked_files, %w{config/database.yml config/client_secrets.json config/application.yml}
#set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# set :default_env, { path: "/opt/ruby/bin:$PATH" }
# set :keep_releases, 5

#after "deploy:assets:symlink", "custom:config"

before 'deploy:check:linked_files', 'custom:upload_secrets'

namespace :deploy do
  # %w[start stop restart].each do |command|
  #   desc "#{command} ccbc-contacts-gmail background services"
  #   task command.to_sym do
  #     on roles(:app) do #except: { :no_release => true } do
  #       # start, stop, or restart the services if the service control script exists
  #       run "if [ -L /etc/init.d/ccbc-contacts-gmail ]; then #{sudo} invoke-rc.d ccbc-contacts-gmail #{command}; fi"
  #     end
  #   end
  # end

  # after :restart, :clear_cache do
  #   on roles(:web), in: :groups, limit: 3, wait: 10 do
  #     # Here we can do anything such as:
  #     # within release_path do
  #     #   execute :rake, 'cache:clear'
  #     # end
  #   end
  # end

  after :finishing, 'deploy:cleanup'

  # dont need this since not installed in a relative uri
  # namespace :assets do
  #   task :precompile do
  #     on roles :web do
  #       within release_path do
  #         with rails_env: fetch(:rails_env), rails_relative_url_root: fetch(:rails_relative_url_root) do
  #           execute :rake, "assets:clobber"
  #           execute :rake, "assets:precompile"
  #         end
  #       end
  #     end
  #   end
  # end

  desc "install ccbc-contacts-gmail background services"
  task :setup_service do
    on roles(:app) do
      # Must occur after code is deployed and symlink to current is created
      # If the service control script does not yet exist, but the script is in our app directory
      # then we link it (to create the service control script) and make sure it's executable
      # and not world-writable.  
      # Otherwise if the service control script already exists, then the script in the app directory
      # may have just been replaced, so make sure it's permissions are like we said.
      execute :sudo, "if [ ! -L /etc/init.d/ccbc-contacts-gmail -a -f #{current_path}/ccbc-contacts-gmail ]; then 
         ln -nfs #{current_path}/ccbc-contacts-gmail /etc/init.d/ccbc-contacts-gmail && 
         chmod +x #{current_path}/ccbc-contacts-gmail && 
         chmod o-w #{current_path}/ccbc-contacts-gmail && 
         update-rc.d ccbc-contacts-gmail defaults ; 
        elif [ -f #{current_path}/ccbc-contacts-gmail ]; then 
         chmod +x #{current_path}/ccbc-contacts-gmail && 
         chmod o-w #{current_path}/ccbc-contacts-gmail ;
        fi"
    end
  end

  desc "remove ccbc-contacts-gmail background services"
  task :remove_service do
    on roles(:app) do
      # if the service control script exists, then remove it and unschedule it
      execute :sudo, "if [ -L /etc/init.d/ccbc-contacts-gmail ]; then 
         unlink /etc/init.d/ccbc-contacts-gmail &&
         update-rc.d ccbc-contacts-gmail remove ;
        fi"
    end
  end

  # before "deploy:remove_service", "deploy:stop"   # stop the service before we remove it
  # before "deploy:update_code", "deploy:stop"      # stop the service before we update the code
  # after "deploy:restart", "deploy:setup_service"  # reinstall/reset perms on service after code changes
  # after "deploy:setup_service", "deploy:start"    # restart the service after its been set up
end

# preserve the nondeployed app config
namespace :custom do
  desc "copy secret config files to shared_path"
  task :upload_secrets do
    on roles(:app) do
      upload! "config/application.yml", "#{shared_path}/config/application.yml", via: :scp
      upload! "config/database.yml", "#{shared_path}/config/database.yml", via: :scp
      upload! "config/client_secrets.json", "#{shared_path}/config/client_secrets.json", via: :scp
    end
  end
end
