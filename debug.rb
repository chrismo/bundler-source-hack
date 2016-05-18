def debug_source_hack(dir, gem_name)
  require 'bundler/cli'
  require 'bundler/cli/update'

  ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')

  Dir.chdir(dir) do
    Bundler.with_clean_env do
      Bundler.ui = Bundler::UI::Shell.new
      Bundler::CLI::Update.new({:source => [gem_name]}, []).run
    end
  end
end

# you should manually alter the Gemfile before running this
def debug_bundle_install_conservative(dir)
  require 'bundler/cli'
  require 'bundler/cli/install'

  ENV['BUNDLE_GEMFILE'] = File.join(dir, 'Gemfile')

  Dir.chdir(dir) do
    Bundler.with_clean_env do
      Bundler.ui = Bundler::UI::Shell.new
      Bundler::CLI::Install.new({}).run
    end
  end
end

if __FILE__ == $0
  debug_source_hack(File.join(File.dirname(__FILE__), 'mail-gem-success'), 'mail')
  #debug_bundle_install_conservative(File.join(File.dirname(__FILE__), 'mail-gem-success'))
end
