module Rack #:nodoc:

  # A minimal router providing just what is needed for the OAuth and OpenID
  # filters.
  class Router

    # Create an instance of Router to match on method, path and params.
    def initialize(method, path, params=[])
      @method = method.to_s.upcase; @path = path; @params = params
    end

    # By overriding the case comparison operator, we can match routes in a case
    # statement.
    #
    # See also: CloudKit::Util#r, CloudKit::Request#match?
    def ===(request)
      request.match?(@method, @path, @params)
    end
  end
end
