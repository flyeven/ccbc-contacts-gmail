class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  rescue_from Exception do |exception|
    # notify_airbrake exception
    Rails.logger.error(exception.inspect)
    Rails.logger.error(exception.backtrace.join("\n"))
    message = exception.message
    if message.length > 1024
      # too big will blow the cookie size limit
      message = "Please see the error log for additional information."
    end
    redirect_to :root, alert: "Sorry, we encountered a problem and have returned you to the home page to try again. [" + message + "]"
  end if Rails.env.downcase == "production"

  rescue_from ActionController::InvalidAuthenticityToken, with: :timed_out_handler
  rescue_from SessionTimedOut, with: :timed_out_handler

  def timed_out_handler(exception)
    redirect_to :root, alert: "Your connection seems to have timed out.  Please start over and try again."
  end

  # this doesn't really catch them on its own, so we have to direct unmatched routes to the not_found method below
  rescue_from ActionController::RoutingError do |exception|
    redirect_to :root #, alert: "We could not find the page you were looking for.  Try starting here."
  end

  def raise_not_found!
    raise ActionController::RoutingError.new("No route matches #{params[:unmatched_route]}")
  end
end
