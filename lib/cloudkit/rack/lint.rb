module Rack #:nodoc:
  class Lint #:nodoc:
    class InputWrapper

      # Rack::Lint wraps StringIO but does not pass #string to the underlying
      # object. This patch fixes the issue.
      def string
        @input.string
      end
    end
  end
end
