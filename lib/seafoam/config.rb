module Seafoam
  # Finds and loads configuration.
  class Config
    def initialize
      @dot_dir = find_dot_dir
    end

    # Load the configuration.
    def load_config
      config_file = File.expand_path('config', @dot_dir)
      if File.exist?(config_file)
        puts "loading config #{config_file}" if $DEBUG
        load config_file
      end
    end

    private

    # Walk up the directory chain from the current directory to root, looking
    # for .seafoam.
    def find_dot_dir
      dir = Dir.getwd
      loop do
        dot_dir = File.expand_path('.seafoam', dir)
        return dot_dir if Dir.exist?(dot_dir)

        new_dir = File.expand_path('..', dir)
        break if new_dir == dir
        dir = new_dir
      end
    end
  end
end
