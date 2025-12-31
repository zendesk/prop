require_relative "lib/prop/version"

Gem::Specification.new "prop", Prop::VERSION do |s|
  s.license = "Apache License Version 2.0"

  s.summary = "Gem for implementing rate limits."

  s.authors  = ["Morten Primdahl"]
  s.email    = 'primdahl@me.com'
  s.homepage = 'https://github.com/zendesk/prop'

  s.required_ruby_version = '>= 3.2'
  s.files = `git ls-files lib LICENSE README.md`.split("\n")
end
