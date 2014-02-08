class Importer

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
      { name: 'groups', title: 'Include Groups Belonged To', value: 1 },
      { name: 'passions', title: 'Include Passions', value: 1 },
      { name: 'abilities', title: 'Include Skills and Abilities', value: 1 }
    ],

    photos: [
      { name: 'replace_photo', title: 'Replace Existing Photo', value: 0 },
      { name: 'family_photo', title: 'Use Family Photo if No Individual', value: 1 }
    ]
  }

  # return options
  def self.options(overrides = {})
    opts = IMPORT_OPTIONS.dup

    if !overrides.blank?
      overrides.each do |k, v|
        if opts.include?(k)
          v.each do |h|
            opts[k].each do |oh| 
              if oh[:name] == h[:name]
                oh[:value] = h[:value]
                break
              end
            end
          end
        end
      end
    end

    opts
  end



# extract all this to a class so we can schedule via dj
  # returns counts added, updated, deleted, and skipped
  def self.perform_import(user)
    # validate parameter
    if user.nil?
      raise ArgumentException, "user cannot be nil"
    end

    # get the user's access token
    google_api_client = Google::APIClient.new(application_name: APP_NAME, application_version: VERSION)
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
    since = user.since.nil? ? Date.new(1980, 1, 1).strftime("%F") : (user.since - 1).strftime("%F")
    ccb_individuals = ChurchCommunityBuilder::Search.all_individual_profiles(since)
    #ccb_individuals = [ChurchCommunityBuilder::Individual.load_by_id(382)]

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
          if option_set?(options, "membership") and !i.membership_type["content"].blank?
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
            nc.content << "Marital Status: #{i.marital_status}\n"
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

# TODO: load other notes options data: significant dates, passions, skills and abilities, etc.


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
  def self.option_set?(options, name)
    results = false
    options.each do |k,v|
      results = (results or !v.select{|h| h[:name] == name and h[:value] == 1}.blank?)
      break if results
    end

    results
  end

  # check to see if the image is a stock_image (or empty)
  def self.stock_image?(image_url)
    results = image_url.blank?
    results = results or File.basename(image_url) == "profile-default.gif" or 
      !image_url.include?("?") or File.basename(image_url) == "group-sm-default.gif"
  end

  def self.present_and_public?(individual, key)
# TODO: respect levels like friends, group members, etc.
    value = individual.send key if individual.respond_to?(key)
# TODO: uncomment to start enforcing privacy
    !value.blank? #&& (individual.privacy_settings.include?(key) ? individual.privacy_settings[key]["id"] >= "3" : true)
  end

  def self.find_contact(contacts, ccb_id)
    matches = contacts.select do |contact|
      ccb_ids = contact.udf('ccb_id')
      ccb_ids.is_a?(Array) && !ccb_ids.empty? && ccb_ids.first == ccb_id
    end

    matches.first if !matches.nil?
  end

  # raw http_request for urls other than google contact
  def self.raw_http_request(image_url, options = {})
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

  # Initializes the ccb_api with the credentials for the specified or default subdomain.
  # returns subdomain that was initialized
  def self.initialize_ccb_api(subdomain)
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

end