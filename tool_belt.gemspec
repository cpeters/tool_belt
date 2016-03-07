$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "tool_belt/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |gem|
  gem.name        = "tool_belt"
  gem.version     = ToolBelt::VERSION
  gem.authors     = ["N/A"]
  gem.email       = ["foreman-dev@googlegroups.com"]
  gem.homepage    = "http://www.katello.org"
  gem.summary     = ""
  gem.description = ""

  gem.files = Dir["{lib,config}/**/*"] + ["LICENSE.txt", "README.md"]

  gem.require_paths = ["lib"]

  # Core Dependencies
  gem.add_dependency "clamp"
  gem.add_dependency "rest-client"
  gem.add_dependency "rodzilla"
end

