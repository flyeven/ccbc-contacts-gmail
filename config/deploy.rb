# config valid only for Capistrano 3.1
lock '3.1.0'

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

# set :linked_files, %w{config/database.yml}
# set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

# set :default_env, { path: "/opt/ruby/bin:$PATH" }
# set :keep_releases, 5

#after "deploy:assets:symlink", "custom:config"


namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

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
end

# preserve the nondeployed app config
namespace :custom do
  desc "copy secret files to shared_path"
  task :setup do
    on roles(:app) do
      upload! "config/application.yml", "#{shared_path}/application.yml", via: :scp
      upload! "config/database.yml", "#{shared_path}/database.yml", via: :scp
      upload! "config/client_secrets.json", "#{shared_path}/client_secrets.json", via: :scp
    end
  end

  task :config do
    on roles(:app) do
      run <<-END
        ln -nfs #{shared_path}/application.yml #{release_path}/config/application.yml
        ln -nfs #{shared_path}/database.yml #{release_path}/config/database.yml
        ln -nfs #{shared_path}/client_secrets.json #{release_path}/config/client_secrets.json
      END
    end
  end
end
