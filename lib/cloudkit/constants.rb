module CloudKit
  module Constants

    # The key used to store the authenticated user.
    CLOUDKIT_AUTH_KEY = 'cloudkit.user'.freeze

    # The key used to indicate the presence of auth in a stack.
    CLOUDKIT_AUTH_PRESENCE = 'cloudkit.auth'.freeze

    # The key used to store auth challenge headers shared between
    # OpenID and OAuth middleware.
    CLOUDKIT_AUTH_CHALLENGE = 'cloudkit.challenge'.freeze

    # The 'via' key used to announce and track upstream middleware.
    CLOUDKIT_VIA = 'cloudkit.via'.freeze

    # The key used to store the 'flash' in the session.
    CLOUDKIT_FLASH = 'cloudkit.flash'.freeze

    # The 'via' key for the OAuth filter.
    CLOUDKIT_OAUTH_FILTER_KEY = 'cloudkit.filter.oauth'.freeze

    # The 'via' key for the OpenID filter.
    CLOUDKIT_OPENID_FILTER_KEY = 'cloudkit.filter.openid'.freeze

    # The key for the login URL used in OpenID and OAuth middleware
    # components.
    CLOUDKIT_LOGIN_URL = 'cloudkit.filter.openid.url.login'.freeze

    # The key for the logout URL used in OpenID and OAuth middleware
    # components.
    CLOUDKIT_LOGOUT_URL = 'cloudkit.filter.openid.url.logout'.freeze
  end
end
