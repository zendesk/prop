$LOAD_PATH.unshift "lib"
require "prop"

Gem::Specification.new "prop", Prop::VERSION do |s|
  s.license = "Apache License Version 2.0"

  s.summary = "Gem for implementing rate limits."

  s.authors  = ["Morten Primdahl"]
  s.email    = 'primdahl@me.com'
  s.homepage = 'https://github.com/zendesk/prop'

  s.add_development_dependency('rake')
  s.add_development_dependency('maxitest')
  s.add_development_dependency('mocha')
  s.add_development_dependency('activesupport')
  s.add_development_dependency('bump')

  s.required_ruby_version = '>= 2.0'
  s.files = `git ls-files lib LICENSE README.md`.split("\n")
end
