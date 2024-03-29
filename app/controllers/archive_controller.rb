# frozen_string_literal: true

class ArchiveController < ApplicationController
  protect_from_forgery with: :null_session

  def user_is_authorized?
    set_variables
    recaptcha_success?
  end

  def status
    if user_is_authorized?
      render plain: @archive_file.display_status
    else
      render plain: 'action unavailable', status: 403
    end
  end

  def download_request
    if user_is_authorized?
      result = @archive_file.get!(request_metadata)
      if result[:file_path].present?
        send_file(result[:file_path], filename: result[:filename])
      else
        unless result[:message]
          Rails.logger.error("Message missing from #{@archive_file} result: #{result}")
          result[:message] = 'Request failed.  Please request technical support.'
        end
        if result[:alert]
          redirect_back fallback_location: root_url, alert: result[:message]
        else
          redirect_back fallback_location: root_url, notice: result[:message]
        end
      end
    else
      @archive_file.log_denied_attempt!(request_metadata)
      redirect_back fallback_location: root_url, alert: 'Action requires successful recaptcha completion.'
    end
  end

  private
    def variable_params
      params.permit(:collection, :object, :format, :request, 'g-recaptcha-response'.to_sym, 'g-recaptcha-response-data'.to_sym => [:sda_request])
    end

    def set_variables
      @collection = params[:collection]
      @object = "#{variable_params[:object]}.#{variable_params[:format]}"
      @archive_file = ArchiveFile.new(collection: @collection, object: @object)
    end

    def recaptcha_success?
      return true unless Settings.recaptcha.use?
      v3_success = verify_recaptcha(action: 'sda_request', minimum_score: Settings.recaptcha.minimum_score.to_f, secret_key: Settings.recaptcha.v3.secret_key)
      v2_success = verify_recaptcha unless v3_success
      v3_success || v2_success
    end
  
    def request_metadata
      user_metadata = { time: Time.now, user: current_user&.email }
      user_metadata.merge!(recaptcha: recaptcha_reply || {}) if Settings.recaptcha.use?
      user_metadata
    end
end
