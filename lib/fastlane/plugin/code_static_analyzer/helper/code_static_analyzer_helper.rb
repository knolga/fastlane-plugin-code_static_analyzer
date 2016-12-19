module Fastlane
  module Helper
    class CodeStaticAnalyzerHelper
      # class methods that you define here become available in your action
      # as `Helper::CodeStaticAnalyzerHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the code_static_analyzer plugin helper!")
      end
    end
  end
end
