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
    #access_type = "online"
    access_type = ""
    if params.include?(:recur) and params[:recur] == "1"
      #access_type = "offline"
      access_type = "&access_type=offline"
    end
    client_secrets = Google::APIClient::ClientSecrets.load('config/client_secrets.json')
    redirect_to client_secrets.authorization_uri.to_s + 
      "?response_type=code" + 
      "&scope=#{GAPI_SCOPE}" +
      "&redirect_uri=#{oauth2callback_url}" +
      "&client_id=#{client_secrets.client_id}" + 
      "&approval_prompt=#{GAPI_APPROVAL_PROMPT}" +
      "#{access_type}",
      status: 303
      #"&access_type=#{access_type}",
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

      user = User.find_by(email: email)
      if user.blank?
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
  end

  # STEP 3 - AUTHENTICATE WITH CCB
  def verify
    @connect_status = "success"
    @verify_status = "danger"

    # load defaults
    ccb_subdomain = CCB_SUBDOMAIN
    api_username = CCB_USERNAME
    api_password = CCB_PASSWORD

    if !params[:ccb_subdomain].empty? and !params[:api_username].empty? and !params[:api_password].empty?
      # try specified credentials
      ccb_subdomain = params[:ccb_subdomain]
      api_username = params[:api_username]
      api_password = params[:api_password]
    else
      # use user's settings, if any
      if !@user.ccb_config_id.blank?
        ccb_config = CcbConfig.find(@user.ccb_config_id)
        if ccb_config
          ccb_subdomain = ccb_config.subdomain
          api_username = ccb_config.api_user
          api_password = ccb_config.api_password
        end
      end
    end
    Importer.initialize_ccb_api(ccb_subdomain, api_username, api_password)

    begin
      connection_error = false
      @ccb_individuals = ChurchCommunityBuilder::Search.search_for_person({email: @user.email, include_inactive: false})
    rescue ChurchCommunityBuilderExceptions::UnableToConnectToChurchCommunityBuilder => e
      connection_error = true
    rescue ChurchCommunityBuilderExceptions::InvalidApiCredentials => e
      connection_error = true
    end

    if connection_error
      flash.now[:alert] = "Unable to connect to your ccb site (#{ccb_subdomain}) with the credentials provided.  Please check them and try again."
    elsif @ccb_individuals.empty?
      flash.now[:alert] = "No individual at your ccb site (#{ccb_subdomain}) could be found with that email address."
    elsif @ccb_individuals.count > 1
      flash.now[:alert]  = "Too many individuals at your ccb site (#{ccb_subdomain}) matched that email address."
    else
      if ccb_config.blank?
        # we need to lookup and save the credentials
        CcbConfig.where(subdomain: ccb_subdomain).each do |cc|
          if cc[:api_user] == api_username and cc[:api_password] == api_password
            ccb_config = cc
            break
          end
        end
        if ccb_config.blank?
          ccb_config = CcbConfig.create({subdomain: ccb_subdomain, api_user: api_username, api_password: api_password })
        end
      end
      @user.ccb_id = @ccb_individuals.first.id
      @user.ccb_config_id = ccb_config.id
      @user.save

      redirect_to :verified
    end

    @ccb_subdomain = ccb_subdomain
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
