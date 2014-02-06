module ApplicationHelper
  def revoke_helper
    results = ""
    if @user and !@user.authorization.nil? and !@user.authorization.access_token.nil?
      results << "<div class='container small revoke'>
        #{link_to('Revoke access to my Google information.  <i>(You will need to grant access again if you want to update your contacts.)</i>'.html_safe, 
          revoke_path, class: 'pull-right')} </div>"
    end
    results.html_safe
  end

end
