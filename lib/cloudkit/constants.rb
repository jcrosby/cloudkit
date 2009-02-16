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

    # The key used to store the shared storage URI for the stack.
    CLOUDKIT_STORAGE_URI = 'cloudkit.storage.uri'.freeze

    # This key references the same piece of configuration as
    # CLOUDKIT_STORAGE_URI. Because DataMapper can use either a URI or an
    # options hash, this key is provided for code clarity when using
    # Rack::Config.
    CLOUDKIT_STORAGE_OPTIONS = 'cloudkit.storage.uri'.freeze

    # The key for the login URL used in OpenID and OAuth middleware
    # components.
    CLOUDKIT_LOGIN_URL = 'cloudkit.filter.openid.url.login'.freeze

    # The key for the logout URL used in OpenID and OAuth middleware
    # components.
    CLOUDKIT_LOGOUT_URL = 'cloudkit.filter.openid.url.logout'.freeze

    # The outer namespace key for the JSON store.
    CLOUDKIT_STORE = :cloudkit_json_store.freeze
  end
end
