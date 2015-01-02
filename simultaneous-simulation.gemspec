# -*- encoding: utf-8 -*-
require File.expand_path('../lib/simultaneous-simulation/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Job Vranish"]
  gem.email         = ["job.vranish@gmail.com"]
  gem.description   = %q{A game networking library used to help coordinate state between players}
  gem.summary       = %q{A game networking library}
  gem.homepage      = "https://github.com/jvranish/simultaneous-simulation"

  files = `git ls-files`.split($\)
  gem.files         = files.reject{|f| f.start_with?("examples/") }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "simultaneous-simulation"
  gem.require_paths = ["lib"]
  gem.version       = Simultaneous::Simulation::VERSION
  gem.add_runtime_dependency 'renet', '>= 0.2.0'
end
