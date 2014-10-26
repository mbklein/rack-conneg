$: << File.join(File.dirname(__FILE__),'lib')
require 'rack/conneg/version'

Gem::Specification.new do |s|
  s.name = "rack-conneg"
  s.version = Rack::Conneg::VERSION
  s.summary = "Content Negotiation middleware for Rack applications"
  s.email = "Michael.Klein@oregonstate.edu"
  s.description = "Middleware that provides both file extension and HTTP_ACCEPT-type content negotiation for Rack applications"
  s.authors = ["Michael B. Klein"]
  s.files = `git ls-files`.split($/)
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options << '--main' << 'README.rdoc'
  s.add_dependency 'rack', '>= 1.0'
end
