
role :web, "sirius"                          # Your HTTP server, Apache/etc
role :app, "sirius"                          # This may be the same as your `Web` server
role :db,  "sirius", :primary => true # This is where Rails migrations will run

set :deploy_to, "/blue2/webapps/#{fetch(:application)}"

#after "deploy:update_code", "deploy:migrate"
