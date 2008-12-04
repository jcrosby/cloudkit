module Rack
  class Router
    def initialize(method, path, params=[])
      @method = method.to_s.upcase; @path = path; @params = params
    end

    def ===(request)
      request.match?(@method, @path, @params)
    end
  end
end
