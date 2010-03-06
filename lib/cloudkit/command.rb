module CloudKit
  class Command
    def self.run(args)
      return help unless command = args.first
    end

    def self.help
      puts "CloudKit"
    end
  end
end
