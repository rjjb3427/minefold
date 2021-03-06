class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  respond_to :html

  prepend_before_filter :authenticate_user!

  protect_from_forgery :except => :steam

  # Facebook User
  expose(:user) {
    User.find_for_facebook_oauth(auth, current_user)
  }

  def facebook
    # Signed out, signing in
    if !signed_in? && user
      user.update_from_facebook_auth(auth)
      user.save

      sign_in_and_redirect(user)

    # Signed in, linked a previously linked Facebook account
    elsif signed_in? && user
      flash[:alert] = :account_linked
      redirect_to edit_user_registration_path

    # Signed in, linking Facebook account
    elsif signed_in?
      current_user.accounts << Accounts::Facebook.new(uid: auth.uid)
      current_user.update_from_facebook_auth(auth)

      Bonuses::LinkedFacebookAccount.give_to(current_user)

      current_user.save

      flash[:alert] = :account_linked

      redirect_to edit_user_registration_path

    # Signed out, signing up
    else
      auth['extra']['raw_info'].keep_if do |key,_|
        Accounts::Facebook::EXTRA_ATTRS.include?(key.to_sym)
      end

      session['devise.facebook_data'] = auth
      redirect_to new_user_registration_path
    end
  end

  def steam
    account = Accounts::Steam.new(uid: auth.uid)
    current_user.accounts << account
    current_user.save!

    Bonuses::LinkedSteamAccount.give_to(current_user)

    flash[:alert] = :account_linked

    # TODO: Fix this with auth support
    # hack to set admin to existing TF2 servers
    funpack = Funpack.where(slug: 'team-fortress-2').first
    current_user.created_servers.where(funpack_id: funpack.id).each do |server|
      server.settings['admins'] = account.steam_id.to_s
      server.save!
    end

    redirect_to edit_user_registration_path
  end

private

  def auth
    request.env['omniauth.auth']
  end

end
