module CloudKit
  class FlashSession
    def initialize
      @values = {}
    end

    def []=(k, v)
      @values[k] = v
    end

    def [](k)
      v = @values[k]
      @values[k] = nil
      v
    end
  end
end
