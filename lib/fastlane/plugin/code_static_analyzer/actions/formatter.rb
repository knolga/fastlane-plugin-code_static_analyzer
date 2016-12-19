module Fastlane
  module Actions
    module SharedValues
      FORMATTER_CUSTOM_VALUE = :FORMATTER_CUSTOM_VALUE
    end

    class FormatterAction < Action
      def self.run(params)
        # fastlane will take care of reading in the parameter and fetching the environment variable:
        UI.message "Formatter"
№project = UI.select("Select your project: ", ["Test Project", "Test Workspace"])

        # sh "shellcommand ./path"

        # Actions.lane_context[SharedValues::FORMATTER_CUSTOM_VALUE] = "my_val"
      end

def self.return_status(mystatus)
    UI.message ">>> Exit command status: #{mystatus}"
  end

  def self.xcode_format(scheme)
    UI.message '-----------------------------------------------'
    UI.message ">>> Running Xcode analyze command... on #{scheme}..."
  end

  def self.cpd_format(tokens, language, files_to_exclude, file)
    UI.message '-----------------------------------------------'
    UI.message "min_tokens    : #{tokens}"
    UI.message "language      : #{language}"
    UI.message "exclude_files : #{files_to_exclude}"
    UI.message 'format        : xml'
    UI.message "output_file   : #{file}"
    UI.message '-----------------------------------------------'
  end

  def self.prepare_xml
    UI.message '>>> Preparing result xml file...'
  end
  
      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "A short description with <= 80 characters of what this action does"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports. 
        
        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(key: :api_token,
                                       env_name: "FL_FORMATTER_API_TOKEN", # The name of the environment variable
                                       description: "API Token for FormatterAction", # a short description of this parameter
                                       verify_block: proc do |value|
                                          UI.user_error!("No API token for FormatterAction given, pass using `api_token: 'token'`") unless (value and not value.empty?)
                                          # UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :development,
                                       env_name: "FL_FORMATTER_DEVELOPMENT",
                                       description: "Create a development certificate instead of a distribution one",
                                       is_string: false, # true: verifies the input is a string, false: every kind of value
                                       default_value: false) # the default value if the user didn't provide one
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['FORMATTER_CUSTOM_VALUE', 'A description of what this value contains']
        ]
      end

      def self.return_value
        # If you method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["Your GitHub/Twitter Name"]
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
