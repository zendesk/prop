Gem::Specification.new "prop", "1.2.0" do |s|
  s.license = "Apache License Version 2.0"

  s.summary = "Gem for implementing rate limits."

  s.authors  = ["Morten Primdahl"]
  s.email    = 'primdahl@me.com'
  s.homepage = 'https://github.com/zendesk/prop'

  s.add_development_dependency('rake')
  s.add_development_dependency('bundler')
  s.add_development_dependency('minitest')
  s.add_development_dependency('mocha')

  s.files = `git ls-files lib LICENSE README.md`.split("\n")
end
