# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]

  def create
    if authrized_passkey.present?
      self.resource = authrized_passkey.webauthn_user.user
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      authrized_passkey.update!(last_used_at: Time.current)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      super
    end
  end
  
  # GET /resource/sign_in
  # def new
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end

  private
  
  def authrized_passkey
    return @authrized_passkey if defined?(@authrized_passkey)

    passkey_params = params.require(:passkey).permit(:credential)
    parsed_credential = JSON.parse(passkey_params[:credential]) rescue nil
    return @authrized_passkey = nil unless parsed_credential

    webauthn_credential = WebAuthn::Credential.from_get(parsed_credential)
    # credential IDから対応するパスキーを検索
    passkey = Passkey.find_by(external_id: webauthn_credential.id)
    return @authrized_passkey = nil unless passkey

    stored_authentication_challenge = session[:current_webauthn_authentication_challenge]

    # パスキーの検証
    verified = webauthn_credential.verify(
      stored_authentication_challenge,
      public_key: passkey.public_key,
      sign_count: passkey.sign_count,
      user_verification: "required"
    )

    @authrized_passkey = verified ? passkey : nil
  end
end
