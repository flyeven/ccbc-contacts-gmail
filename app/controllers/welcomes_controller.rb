class WelcomesController < ApplicationController

  before_action :set_user, except: [:connect, :index, :oauth2callback]
  before_action :initialize_easy_steps

  GAPI_SCOPE = "https://www.google.com/m8/feeds%20profile%20https://www.googleapis.com/auth/userinfo.email"
  GAPI_APPROVAL_PROMPT = "force" # force or auto

  #require 'version'
  require 'google/api_client'
  require 'google/api_client/client_secrets'

  # WELCOME 
  def index
    
  end

  # STEP 1 - CONNECT - AUTHENTICATE/AUTHORIZE GOOGLE
  def connect
    access_type = "online"
    if params.include?(:recur) and params[:recur] == "1"
      access_type = "offline"
    end
    client_secrets = Google::APIClient::ClientSecrets.load('config/client_secrets.json')
    redirect_to client_secrets.authorization_uri.to_s + 
      "?response_type=code" + 
      "&scope=#{GAPI_SCOPE}" +
      "&redirect_uri=#{oauth2callback_url}" +
      "&client_id=#{client_secrets.client_id}" + 
      "&approval_prompt=#{GAPI_APPROVAL_PROMPT}" +
      "&access_type=#{access_type}",
      status: 303
  end

  # STEP 1.5 - STORE AUTHORIZATION, REDIRECT TO CONNECTED
  # GET https://www.googleapis.com/plus/v1/people/me?key={YOUR_API_KEY}
  def oauth2callback
    if params[:code]
      client = Google::APIClient.new(application_name: APP_NAME, application_version: VERSION)
      client_secrets = Google::APIClient::ClientSecrets.load('config/client_secrets.json')
      client.authorization = client_secrets.to_authorization
      client.authorization.scope = GAPI_SCOPE
      client.authorization.code = params[:code]
      client.authorization.redirect_uri = oauth2callback_url
      client.authorization.fetch_access_token!

      # get information from google about who the user is
      oauth = client.discovered_api('oauth2')
      results = client.execute!(:api_method => oauth.userinfo.get, :parameters => {"userId" => "me"})
      json_results = JSON.parse(results.body)
      email = json_results["email"]
      name = json_results["name"]
      #verified = json_results["verified_email"]
      #picture = json_results["picture"]

      users = User.where(email: email)
      if !users.blank?
        user = users.first
      else
        user = User.new
        user.email = email
        user.name = name
      end
      user.recurring = !client.authorization.refresh_token.nil?
      user.authorization = client.authorization
      user.save

      session[:user]= user.md5
      
      redirect_to action: :connected
    else
      redirect_to :root, :alert => "Permission was not granted to access your Google information.  This application can't work without it." 
    end
  end

  # STEP 2 - CONNECTED, NEXT - VERIFY
  def connected
    # test to see if this works
    client = Google::APIClient.new(application_name: APP_NAME, application_version: VERSION)
    client.authorization = @user.authorization
    if client.authorization.nil? 
      redirect_to :root, :alert => "We were unable to retrieve your information from Google.  Please try again."
    end
    @connect_status = "success"
    @verify_status = "info"
# TODO: provide user ability to try against a different ccb site    
  end

  # STEP 3 - AUTHENTICATE WITH CCB
  def verify
    @connect_status = "success"
    @verify_status = "danger"

    Importer.initialize_ccb_api(@user.subdomain)
    @ccb_individuals = ChurchCommunityBuilder::Search.search_for_person({email: @user.email, include_inactive: false})
    if @ccb_individuals.empty?
      flash.now[:alert] = "No individual at your ccb site could be found with that email address."
# TODO: provide user ability to try against a different ccb site    
    elsif @ccb_individuals.count > 1
      flash.now[:alert]  = "Too many individuals at your ccb site matched that email address."
    else
      @user.ccb_id = @ccb_individuals.first.id
      @user.save

      redirect_to :verified
    end
  end

  # STEP 3.5 - VERIFIED, NEXT - IMPORT
  def verified
    @connect_status = "success"
    @verify_status = "success"
    @import_status = "info"

    # show how many contacts to update since last visit? if so, cache for performance

    # get default preferences and overlay with user's selections

    @options = Importer.options(@user.options)
  end

  # STEP 4 - IMPORT - UPDATE CONTACTS
  def import
    # save user's preferences
    options = Importer.options
    # since only the checked boxes come over, start with everything unchecked
    options.each do |ok, ov|
      ov.each do |oh|
        oh[:value] = 0
      end
    end
    # now load what the user checked
    params.each do |pk, pv|
      options.each do |ok, ov|
        ov.each do |oh|
          if oh[:name] == pk
            oh[:value] = 1
            break
          end
        end
      end
    end
    @user.options = options
    @user.save

    count_added, count_updated, count_deleted, count_skipped = Importer.perform_import(@user)
    flash.now[:success] = "Finished! #{count_added} added, #{count_updated} updated, #{count_skipped} skipped."
  end

  # STEP 4.5 - IMPORTING
  def importing
  end

  # step 5 - IMPORTED
  def imported
  end

  # OPTION TO REVOKE THE TOKEN https://accounts.google.com/o/oauth2/revoke?token={access_token}
  # manually: https://security.google.com/settings/security/permissions?hl=en&pli=1
  def revoke
    if @user
      client = Google::APIClient.new(application_name: APP_NAME, application_version: VERSION)
      client.authorization = @user.authorization

      if !client.authorization.nil?
        results = client.execute!(:uri => "https://accounts.google.com/o/oauth2/revoke", :parameters => {"token" => client.authorization.access_token})
      end
    end

    reset_session
    redirect_to :root, :alert => "You've just revoked the permissions that you had previously granted to this application."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      md5 = session[:user]
      if md5
        @user = User.find_by(md5: md5)
      else
        raise SessionTimedOut.new('md5 not found')
      end
    end

    # Set the default styles for the easy_steps partial so we can indicate progress
    def initialize_easy_steps
      @connect_status = "info"
      @verify_status = "gray"
      @import_status = "gray"
    end

end
