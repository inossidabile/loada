require File.expand_path("../lib/loada.rb", __FILE__)

Gem::Specification.new do |s|
  s.name        = "loada"
  s.version     = Loada::VERSION
  s.platform    = Gem::Platform::RUBY
  s.summary     = "The Loada"
  s.email       = "boris@staal.io"
  s.homepage    = "http://github.com/inossidabile/loada"
  s.description = "A gem wrapper to include Loada via the asset pipeline"
  s.authors     = ['Boris Staal']

  s.files = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.add_dependency 'sprockets'
end