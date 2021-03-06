require 'fastlane/plugin/code_static_analyzer/version'

module Fastlane
  module CodeStaticAnalyzer
    # Return all .rb files inside the "actions" and "helper" directory
    ROOT = Pathname.new(File.expand_path('../../..', __FILE__))
    def self.all_classes
      Dir[File.expand_path('**/{actions,helper}/*.rb', File.dirname(__FILE__))]
    end
  end
end

# By default we want to import all available actions and helpers
# A plugin can contain any number of actions and plugins
Fastlane::CodeStaticAnalyzer.all_classes.each do |current|
  require current
end
