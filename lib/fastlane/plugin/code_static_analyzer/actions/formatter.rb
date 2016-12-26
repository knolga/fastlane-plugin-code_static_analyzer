module Fastlane
  module Actions
    # module SharedValues
    #   FORMATTER_CUSTOM_VALUE = :FORMATTER_CUSTOM_VALUE
    # end

    class FormatterAction < Action
      def self.run(params)
        # fastlane will take care of reading in the parameter and fetching the environment variable:
        UI.message "Formatter"
      end

      def self.return_status(mystatus)
        UI.message Actions::FormatterAction.light_blue(">>> Exit command status: #{mystatus}")
      end

      def self.xcode_format(scheme)
        UI.message ">>> Running Xcode analyze command... on #{scheme}..."
      end

      def self.cpd_format(tokens, language, exclude, result_file, inspect)
        UI.message "files         : #{inspect}"
        UI.message "min_tokens    : #{tokens}"
        UI.message "language      : #{language}"
        UI.message "exclude_files : #{exclude}"
        UI.message 'format        : xml'
        UI.message "output_file   : #{result_file}"
      end

      # String colorization
      # call UI.message Actions::FormatterAction.light_blue(text)
      def self.light_blue(mytext)
        "\e[36m#{mytext}\e[0m"
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Custom output formatter"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
      end

      def self.available_options
        # Define all options your action supports.
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          # ['FORMATTER_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.return_value
        # If you method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["knolga"]
      end

      def self.is_supported?(platform)
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #

        platform == :ios
      end
    end
  end
end
