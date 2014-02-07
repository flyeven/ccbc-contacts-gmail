class WelcomesController < ApplicationController
  rescue_from Exception, :with => :error_handler

  before_action :set_user, except: [:connect, :index, :oauth2callback]
  before_action :initialize_easy_steps

  MY_APP_NAME = "ccbc-contacts-gmail"
  MY_APP_VERSION = "1.0.0"

  GAPI_SCOPE = "https://www.google.com/m8/feeds%20profile%20https://www.googleapis.com/auth/userinfo.email"
  GAPI_APPROVAL_PROMPT = "force" # force or auto

  IMPORT_OPTIONS = {
    # names must be unique across hashes
    individuals: [
      { name: 'primary', title: 'Include Primary Contacts', value: 1 },
      { name: 'spouse', title: 'Include Spouses', value: 1 },
      { name: 'children_other', title: 'Include Children and Other', value: 0 },
      { name: 'inactive', title: 'Include Inactive', value: 1 },
      { name: 'business', title: 'Include Businesses', value: 0 },
      { name: 'missing_info', title: 'Include if missing Email, Phone, and Address', value: 0 }
    ],

    notes: [
      { name: 'allergies', title: 'Include Known Allergies', value: 1 },
      { name: 'significant_events', title: 'Include Significant Events', value: 1 },
      { name: 'membership', title: 'Include Membership Info', value: 1 },
      { name: 'marital_status', title: 'Include Marital Status', value: 1 },
      { name: 'family_members', title: 'Include Family Members (of Primary and Spouse)', value: 1 },
      { name: 'groups', title: 'Include Groups Belonged To', value: 1 }
    ],

    photos: [
      { name: 'replace_photo', title: 'Replace Existing Photo', value: 0 },
      { name: 'family_photo', title: 'Use Family Photo if No Individual', value: 1 }
    ]
  }

  require 'version'
  require 'google/api_client'
  require 'google/api_client/client_secrets'

  def error_handler(exception)
    redirect_to :root, alert: "Sorry, we encountered a problem and have returned you to the home page to try again. [" + exception.message + "]"
  end

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
      client = Google::APIClient.new(application_name: MY_APP_NAME, application_version: MY_APP_VERSION)
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
      redirect_to :root, :alert => "Permission was not granted to access Google information.  This application can't work without it." 
    end
  end

  # STEP 2 - CONNECTED, NEXT - VERIFY
  def connected
    # test to see if this works
    client = Google::APIClient.new(application_name: MY_APP_NAME, application_version: MY_APP_VERSION)
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

    initialize_ccb_api(@user.subdomain)
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

    @options = IMPORT_OPTIONS.dup
    if @user.options
      @user.options.each do |k, v|
        if @options.include?(k)
          v.each do |h|
            @options[k].each do |oh| 
              if oh[:name] == h[:name]
                oh[:value] = h[:value]
                break
              end
            end
          end
        end
      end
    end
  end

  # STEP 4 - IMPORT - UPDATE CONTACTS
  def import
    # save user's preferences
    options = IMPORT_OPTIONS.dup
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

    begin
      count_added, count_updated, count_deleted, count_skipped = perform_import(@user)
      flash.now[:success] = "Finished! #{count_added} added, #{count_updated} updated, #{count_skipped} skipped."
# TODO: just catch the timeout      
    # rescue => e
    #   redirect_to :root, alert: "Your connection seems to have timed out.  Please try again.  #{e.message}"
    end
  end




# extract all this to a class so we can schedule via dj
  # returns counts added, updated, deleted, and skipped
  def perform_import(user)
    # validate parameter
    if user.nil?
      raise ArgumentException, "user cannot be nil"
    end

    # get the user's access token
    google_api_client = Google::APIClient.new(application_name: MY_APP_NAME, application_version: MY_APP_VERSION)
    google_api_client.authorization = user.authorization
    if google_api_client.authorization.nil? 
      raise ArgumentException, "authorization information is missing"
    end
# TODO: might need to       client.authorization.fetch_access_token!

    # initialize the ccb api
    subdomain = initialize_ccb_api(user.subdomain)

    # identify the gmail groups 
    # ccb_group = "#{subdomain}.ccb" group 
    # my_contacts_group = "my contacts" system group
    contacts_api_client = GContacts::Client.new(:access_token => google_api_client.authorization.access_token)
    groups = contacts_api_client.all(api_type: :groups)
    ccb_group = nil
    my_contacts_group = nil
    groups.each do |g|
      if g.title == subdomain + ".ccb"
        ccb_group = g
      elsif g.data.include?("gContact:systemGroup") and g.data["gContact:systemGroup"].first["@id"] == "Contacts"
        my_contacts_group = g
      end
    end
    # if the custom ccb group doesn't exist yet, then create it
    if !ccb_group
      ccb_group = GContacts::Element.new
      ccb_group.category = "group"
      ccb_group.title = subdomain + ".ccb"
      ccb_group.content = "Group for #{subdomain}.ccbchurch.com individuals."
      ccb_group = contacts_api_client.create!(ccb_group)
    end

    # get up to 5000 of the existing gmail contacts
# TODO: document and maybe raise this limitation
    gmail_contacts = contacts_api_client.all(params: { "max-results" => 5000, "group" => ccb_group.id })


    # get all the individuals that have changed since the last time we updated
    # this user (user.since), overlap a little just to be safe.
    since = @user.since.nil? ? Date.new(1980, 1, 1).strftime("%F") : (user.since - 1).strftime("%F")
    #ccb_individuals = ChurchCommunityBuilder::Search.all_individual_profiles(since)
    ccb_individuals = [ChurchCommunityBuilder::Individual.load_by_id(382)]

    count_added = 0
    count_updated = 0
    count_deleted = 0
    count_skipped = 0
    options = user.options

    # for each ccb individual add to the gmail group if possible
    ccb_individuals.each do |i|
      # find the corresponding gmail contacts record for this individual
      nc = find_contact(gmail_contacts, i.id)

# TODO: need to provide for church leadership getting everyone regardless of their privacy

      if i.privacy_settings["profile_listed"] == "false" and !nc.blank?
# TODO: we need to delete this contact from gmail because the individual wants to be excluded from listings
        Rails.logger.debug("need to delete #{i.full_name} because they requested privacy")
        count_skipped += 1
      elsif i.privacy_settings["profile_listed"] == "false"
        Rails.logger.debug("skipping #{i.full_name} due to privacy request")
        count_skipped += 1
      elsif !option_set?(options, 'primary') and i.family_position == "Primary Contact"
        Rails.logger.debug("skipping #{i.full_name} due to being a Primary Contact")
        count_skipped += 1
      elsif !option_set?(options, 'business') and i.family_position == "Business"
        Rails.logger.debug("skipping #{i.full_name} due to business listing")
        count_skipped += 1
      elsif !option_set?(options, 'inactive') and i.active == "false"
        Rails.logger.debug("skipping #{i.full_name} due to inactive")
        count_skipped += 1
      elsif !option_set?(options, 'spouse') and i.family_position == "Spouse"
        Rails.logger.debug("skipping #{i.full_name} due to being a Spouse")
        count_skipped += 1
      elsif !option_set?(options, 'children_other') and !["Business", "Primary Contact", "Spouse"].include?(i.family_position)
        Rails.logger.debug("skipping #{i.full_name} due to being a Child or Other")
        count_skipped += 1
      else

        # gather info that might be missing which may mean we want to exclude them
        addresses, emails, phones = [], [], []
        emails << { "@rel" => "http://schemas.google.com/g/2005#other", "@address" => i.email, "@primary" => "true" } if !i.email.blank?

        # set phones
        { "mobile" => "mobile_phone",
          "main" => "contact_phone",
          "work" => "work_phone",
          "home" => "home_phone"
        }.each do |type, key|
          phones << { "@rel" => "http://schemas.google.com/g/2005##{type}", "text" => i.send(key) } if present_and_public?(i, key)
        end

        # set addresses
        { 
          "other" => "other_address",
          "other" => "mailing_address",
          "work" => "work_address",
          "home" => "home_address"
        }.each do |type, key|
          line_1 = eval("i.#{key}.line_1") rescue nil
          line_2 = eval("i.#{key}.line_2") rescue nil

          addresses << { "gd:formattedAddress" => line_1 + "\n" + line_2,
            "@rel" => "http://schemas.google.com/g/2005##{type}" } if !line_1.blank? && !line_2.blank?  && present_and_public?(i, key)
        end

        if !option_set?(options, 'missing_info') and phones.empty? and emails.empty? and addresses.empty?
          Rails.logger.debug("skipping #{i.full_name} due to empty contact details")
          count_skipped += 1
        else
          # create a gmail contact record if we didnt find an existing one
          if !nc
            nc = GContacts::Element.new
            nc.category = "contact"
          end

          # set membership in ccb_subdomain contact group
          nc.groups = []
          nc.groups << ccb_group.id
          nc.groups << my_contacts_group.id

          ## build the notes (from scratch)
          nc.content = ""

          # indicate allergies
          if option_set?(options, "allergies") and present_and_public?(i, 'allergies')
            nc.content << "Allergies: #{i.allergies}\n"
          end

          # indicate membership type and family members in comments
          if option_set?(options, "membership")
            nc.content << i.membership_type["content"]
            if i.membership_end.blank? and i.membership_date.blank?
              # no range specified
            elsif !i.membership_end.blank? and !i.membership_date.blank?
              nc.content << " (#{DateTime.parse(i.membership_date).strftime("%B %e, %Y")} - #{DateTime.parse(i.membership_end).strftime("%B %e, %Y")})"
            elsif i.membership_end.blank?
              nc.content << " (since #{DateTime.parse(i.membership_date).strftime("%B %e, %Y")})"
            end
            nc.content << "\n"
          end

          # indicate marital status
          if option_set?(options, 'marital_status') and present_and_public?(i, 'marital_status')
            nc.content << "Marital Status: #{marital_status}\n"
          end

          # indicate anniversary
          if present_and_public?(i, 'anniversary')
            nc.content << "Anniversary: " + DateTime.parse(i.anniversary).strftime("%B %e, %Y") + "\n"
          end

          if i.family_position == "Primary Contact" or i.family_position == "Spouse"
            # load all family relations
            i.family_members["family_member"].each do |data|
              nc.content << data["family_position"] + ": " + data["individual"]["content"] + "\n"
            end unless i.family_members.blank?
          else
            # just load primary contact
            i.family_members["family_member"].each do |data|
              if data["family_position"] == "Primary Contact"
                nc.content << data["family_position"] + ": " + data["individual"]["content"] + "\n"
              end
            end unless i.family_members.blank?
          end

# TODO: load other notes options data and maybe passions, skills, etc.


  # TODO: maybe we have to go to the family record to get stuff like phone numbers and addresses?
          data = {
            "gd:name" => { "gd:fullName" => i.full_name },
            "gd:email" => emails,
            "gd:phoneNumber" => phones,
            "gd:structuredPostalAddress" => addresses,
            "gContact:userDefinedField" => [ { "@key" => "ccb_id", "@value" => i.id.to_s } ]
          }

          # set birthday
          if present_and_public?(i, 'birthday')
            data["gContact:birthday"] = { "@when" => i.birthday } 
          else
            # remove it?
            data.delete("gContact:birthday") if data.include?("gContact:birthday")
          end

          # add or update the contact record
          nc.data = data
          if nc.id.nil?
            Rails.logger.debug("adding #{nc.data["gd:name"]["gd:fullName"]}")
            nc = contacts_api_client.create!(nc)
            #gmail_contacts << nc
            count_added += 1
          else
            Rails.logger.debug("updating #{nc.data["gd:name"]["gd:fullName"]}")
            nc = contacts_api_client.update!(nc)
            count_updated += 1
          end

  # TODO: batch all this stuff
  # TODO: support recurring

          # if there is no contact photo yet or we are allowed to overwrite the photo
          if nc.photo_etag.blank? or option_set?(options, "replace_photo")
            # if no image exists for the individual or it is the stock image
            # and we are allowed to use the family one instead then try it
            image_url = i.image
            if stock_image?(image_url) and option_set?(options, "family_photo")
              image_url = i.family_image
            end
            # if we have a valid photo from ccb then get it
            if !stock_image?(image_url)
              # fetch the image from ccb
              results = raw_http_request(i.image)
              begin
                # upload it to the gmail contact record, but sometimes google will prevent this
                # i think they do that when their email is associated with a google plus account
                contacts_api_client.update_photo!(nc, results.body, "image/*")
              rescue => e
# TODO: we will want to report on this somehow
Rails.logger.error("could not update photo for #{i.full_name} #{e.message}")
              end
            else
              # should we wipeout the existing image if the user cleared theirs out at ccb?
            end
          end
        end
      end
    end

# TODO: need to loop through the gmail_contacts and remove those that... ?

    # indicate when the user's ccb individuals were last imported
    user.since = Date.today
    user.save

    return count_added, count_updated, count_deleted, count_skipped
  end

  # returns true if the named option is set
  def option_set?(options, name)
    results = false
    options.each do |k,v|
      results = (results or !v.select{|h| h[:name] == name and h[:value] == 1}.blank?)
      break if results
    end

    results
  end

  # check to see if the image is a stock_image (or empty)
  def stock_image?(image_url)
    results = image_url.blank?
    results = results or File.basename(image_url) == "profile-default.gif" or 
      !image_url.include?("?") or File.basename(image_url) == "group-sm-default.gif"
  end

  # STEP 4.5 - IMPORTED
  def imported
  end

  # OPTION TO REVOKE THE TOKEN https://accounts.google.com/o/oauth2/revoke?token={access_token}
  # manually: https://security.google.com/settings/security/permissions?hl=en&pli=1
  def revoke
    if @user
      client = Google::APIClient.new(application_name: MY_APP_NAME, application_version: MY_APP_VERSION)
      client.authorization = @user.authorization

      if !client.authorization.nil?
        results = client.execute!(:uri => "https://accounts.google.com/o/oauth2/revoke", :parameters => {"token" => client.authorization.access_token})
      end
    end

    reset_session
    redirect_to :root, :alert => "You've just revoked the permissions that you had previously granted to this application."
  end


  def present_and_public?(individual, key)
# TODO: respect levels like friends, group members, etc.
    value = individual.send key if individual.respond_to?(key)
# TODO: uncomment to start enforcing privacy
    !value.blank? #&& (individual.privacy_settings.include?(key) ? individual.privacy_settings[key]["id"] >= "3" : true)
  end

  def find_contact(contacts, ccb_id)
    matches = contacts.select do |contact|
      ccb_ids = contact.udf('ccb_id')
      ccb_ids.is_a?(Array) && !ccb_ids.empty? && ccb_ids.first == ccb_id
    end

    matches.first if !matches.nil?
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      md5 = session[:user]
      if md5
        @user = User.find_by(md5: md5)
      end

      redirect_to :root if @user.nil?
    end

    # Set the default styles for the easy_steps partial so we can indicate progress
    def initialize_easy_steps
      @connect_status = "info"
      @verify_status = "gray"
      @import_status = "gray"
    end

    # Initializes the ccb_api with the credentials for the specified or default subdomain.
    # returns subdomain that was initialized
    def initialize_ccb_api(subdomain)
      api_subdomain = CCB_SUBDOMAIN
      api_user = CCB_USERNAME
      api_password = CCB_PASSWORD

      if subdomain
        ccb_config = CcbConfig.find_by(subdomain: subdomain)
        if ccb_config
          api_subdomain = ccb_config.subdomain
          api_user = ccb_config.api_user
          api_password = ccb_config.api_password
        end
      end
      ChurchCommunityBuilder::Api.connect(api_user, api_password, api_subdomain)

      api_subdomain
    end

    # raw http_request for urls other than google contact
    def raw_http_request(image_url, options = {})
      uri = URI.parse(image_url)
      Net::HTTP.start(uri.host, uri.port,
        :use_ssl => uri.scheme == 'https') do |http|

        http.set_debug_output(options[:debug_output]) if options[:debug_output]
        if options[:verify_ssl]
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        else
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        response = http.request_get(uri.to_s)
        return response
      end
    end

end
