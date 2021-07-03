# frozen_string_literal: true

class Auth::GoogleOAuth2Authenticator < Auth::ManagedAuthenticator
  GROUPS_SCOPE ||= "admin.directory.group.readonly"
  GROUPS_URL ||= "https://admin.googleapis.com/admin/directory/v1/groups"

  class DiscourseGoogleOauth2 < OmniAuth::Strategies::GoogleOauth2
    def call_app!
      # Incremental authorization for group info
      return render_group_confirmation! if on_callback_path? && should_ask_for_groups?
      super
    end

    def has_group_scope?
      request.params['scope']&.split&.include?("#{BASE_SCOPE_URL}#{GROUPS_SCOPE}")
    end

    def should_ask_for_groups?
      return false if !SiteSetting.google_oauth2_hd_groups.present?
      return false if has_group_scope?
      hd = env['omniauth.auth'][:extra].dig(:raw_info, :hd)
      SiteSetting.google_oauth2_hd_groups.split('|').include?(hd)
    end

    def render_group_confirmation!
      token = CSRFTokenVerifier.new.tap { |v| v.call(env) }.form_authenticity_token

      new_params = request.params.merge(scope: GROUPS_SCOPE)
      request_url = full_host + script_name + request_path + "?scope=#{GROUPS_SCOPE}"
      OmniAuth::Form.build(title: "Request groups?", url: request_url) do
        html "\n<input type='hidden' name='authenticity_token' value='#{token}'/>"
        button "Continue"
      end.to_response
    end

    def raw_groups
      return nil if !has_group_scope?
      @group_info ||= begin
        groups = []
        page_token = nil
        loop do
          response = access_token.get(GROUPS_URL, params: {
            userKey: uid,
            pageToken: page_token
          }).parsed
          groups.push(*response['groups'])
          page_token = response['nextPageToken']
          break if page_token.nil?
        end
        groups
      end
    end

    extra do
      { raw_groups: raw_groups }
    end
  end

  def name
    "google_oauth2"
  end

  def enabled?
    SiteSetting.enable_google_oauth2_logins
  end

  def primary_email_verified?(auth_token)
    # note, emails that come back from google via omniauth are always valid
    # this protects against future regressions
    auth_token[:extra][:raw_info][:email_verified]
  end

  def register_middleware(omniauth)
    options = {
      setup: lambda { |env|
        strategy = env["omniauth.strategy"]
        strategy.options[:client_id] = SiteSetting.google_oauth2_client_id
        strategy.options[:client_secret] = SiteSetting.google_oauth2_client_secret

        hd = SiteSetting.google_oauth2_hd
        strategy.options[:hd] = hd if hd.present?

        if (google_oauth2_prompt = SiteSetting.google_oauth2_prompt).present?
          strategy.options[:prompt] = google_oauth2_prompt.gsub("|", " ")
        end

        # All the data we need for the `info` and `credentials` auth hash
        # are obtained via the user info API, not the JWT. Using and verifying
        # the JWT can fail due to clock skew, so let's skip it completely.
        # https://github.com/zquestz/omniauth-google-oauth2/pull/392
        strategy.options[:skip_jwt] = true

        hd_groups = SiteSetting.google_oauth2_hd_groups
        if hd_groups.present? && hd == hd_groups
          # Only one hosted domain is allowed. Always request group info
          strategy.options[:scope] = "#{DEFAULT_SCOPE},#{GROUPS_SCOPE}"
        elsif hd_groups.present?
          # Use incremental authorization
          strategy.options[:include_granted_scopes] = true
        end
      }
    }
    omniauth.provider DiscourseGoogleOauth2, options
  end

  def after_authenticate(auth_token, existing_account: nil)
    @auth_result = super
    if raw_groups = auth_token[:extra][:raw_groups]
      hd = auth_token[:extra][:raw_info][:hd]
      @auth_result.groups = raw_groups.map do |google_group|
        {
          name: "#{hd}:#{google_group["name"]}",
          id: google_group["id"]
        }
      end
    end
    @auth_result
  end
end
