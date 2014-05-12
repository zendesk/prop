Gem::Specification.new "prop", "1.0.2" do |s|
  s.name              = 'prop'
  s.version           = '1.0.2'
  s.date              = '2012-04-24'
  s.rubyforge_project = 'prop'
  s.license           = "Apache License Version 2.0"

  s.summary     = "Gem for implementing rate limits."
  s.description = "Gem for implementing rate limits."

  s.authors  = ["Morten Primdahl"]
  s.email    = 'primdahl@me.com'
  s.homepage = 'http://github.com/zendesk/prop'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  s.add_development_dependency('rake')
  s.add_development_dependency('bundler')
  s.add_development_dependency('minitest')
  s.add_development_dependency('mocha')

  s.files = `git ls-files`.split("\n")
  s.test_files = s.files.select { |path| path =~ /^test\/test_.*\.rb/ }
end
