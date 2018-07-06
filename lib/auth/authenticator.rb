# this class is used by the user and omniauth controllers, it controls how
#  an authentication system interacts with our database and middleware

class Auth::Authenticator
  def name
    raise NotImplementedError
  end

  def enabled?
    # Log if this has not been overridden. Eventually should raise an exception, but this will break existing plugins
    Rails.logger.warn("Auth::Authenticator subclasses should define an enabled? function. Defaulting to true.")
    true
  end

  def after_authenticate(auth_options)
    raise NotImplementedError
  end

  # can be used to hook in after the authentication process
  #  to ensure records exist for the provider in the db
  #  this MUST be implemented for authenticators that do not
  #  trust email
  def after_create_account(user, auth)
    # not required
  end

  # hook used for registering omniauth middleware,
  #  without this we can not authenticate
  def register_middleware(omniauth)
    raise NotImplementedError
  end

  # optionally return a string describing the connected account
  #  for a given user (typically email address). Used to list
  #  connected accounts under the user's preferences.
  def description_for_user(user)
    # not required
  end

  # can authorisation for this provider be revoked?
  def can_revoke?
    false
  end

  # optionally implement the ability for users to revoke
  #  their link with this authenticator.
  # should ideally contact the third party to fully revoke
  #  permissions. If this fails, return :remote_failed.
  # skip remote if skip_remote == true
  def revoke(user, skip_remote = false)
    raise NotImplementedError
  end
end
