# const_missing(name) — fires when referencing an undefined constant
# Rails uses this for autoloading: referencing User loads app/models/user.rb

module AutoLoader
  def self.const_missing(name)
    puts "[AutoLoader] #{name} not found, attempting to load..."

    file = name.to_s
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')  # HTTPClient → HTTP_Client
      .gsub(/([a-z])([A-Z])/, '\1_\2')         # UserProfile → User_Profile
      .downcase                                 # User_Profile → user_profile

    path = File.join(__dir__, "autoload_examples", "#{file}.rb")

    if File.exist?(path)
      require path
      const_get(name)
    else
      super
    end
  end
end

# Create sample files to autoload
dir = File.join(__dir__, "autoload_examples")
Dir.mkdir(dir) unless Dir.exist?(dir)

File.write(File.join(dir, "greeter.rb"), <<~RUBY)
  module AutoLoader
    class Greeter
      def hello
        "Hello from autoloaded Greeter!"
      end
    end
  end
RUBY

# This triggers const_missing, which loads the file
puts AutoLoader::Greeter.new.hello

# This triggers const_missing but file doesn't exist
begin
  AutoLoader::NonExistent
rescue NameError => e
  puts "Caught: #{e.message}"
end
