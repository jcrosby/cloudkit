module CloudKit
  
  # FlashSessions are hashes that forget their contents after the first access.
  # Useful for session-based messaging.
  class FlashSession
    def initialize
      @values = {}
    end

    # Set the value for a key.
    def []=(k, v)
      @values[k] = v
    end

    # Access a value, then forget it.
    def [](k)
      @values.delete(k)
    end
  end
end
