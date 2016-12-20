module Fastlane
  module Actions
    module SharedValues
      CPD_ANALYZER_STATUS = :CPD_ANALYZER_STATUS
    end

    class CpdAnalyzerAction < Action
      def self.run(params)
        filepathname = "#{params[:dir]}copypaste.xml"
        tokens = params[:tokens]
        files = params[:files_to_inspect]
        lan = params[:language]
        files_to_exclude = params[:files_to_exclude]
        
        UI.header('Run copy-paste detector')
        exclude_files = ''
   
        files_to_exclude.each do |exclude|
          exclude_files += "#{exclude} "
        end
       run_script = "pmd cpd "\
	 				"--minimum-tokens #{tokens} "\
 					"--files #{files} "\
 					"--language #{lan} "\
 					"--exclude #{exclude_files}"\
 					"--format xml > '#{filepathname}'"
       Actions::FormatterAction.cpd_format(tokens,lan,files_to_exclude,filepathname)
       FastlaneCore::CommandExecutor.execute(command: "#{run_script}",
                                   print_all: false,
                                       error: proc do |error_output|
                                         # handle error here
                                       end)
       status = $?.exitstatus
       xml_content = Actions::JunitParserAction.parse_xml_to_xml(filepathname)

		junit_xml = Actions::JunitParserAction.add_testsuite('', 'copypaste', xml_content)
      
        # create full file with results
		Actions::JunitParserAction.create_code_analysis_junit_xml(junit_xml, "#{params[:dir]}codeAnalysResults_cpd")

        Actions.lane_context[SharedValues::CPD_ANALYZER_STATUS] = status
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
          FastlaneCore::ConfigItem.new(key: :dir,  #insert check block if path exist and string ends by /
                     					description: "Path to result file",
                        				optional: true,
                            			type: String,
                   						default_value: './artifacts/'),    
			FastlaneCore::ConfigItem.new(key: :tokens,
                        				env_name: "CPD_TOKENS",
                     					description: "The min number of words in code that is detected as copy paste",
                        				optional: true,
                            			type: String,
                   						default_value: '100'),
			FastlaneCore::ConfigItem.new(key: :files_to_inspect, 
                        				env_name: "CPD_FILES_TO_INSPECT",
                     					description: "Path to dir/file to be inspected on copy paste",
                        				optional: false,
                            			type: String),
			FastlaneCore::ConfigItem.new(key: :files_to_exclude, 
                                   		env_name: "CPD_FILES_NOT_TO_INSPECT",
                                		description: "Path to dir/file not to be inspected on copy paste",
                                   		optional: false,
                                       	type: Array),
            FastlaneCore::ConfigItem.new(key: :language, 
                                   		env_name: "CPD_FILE_LANGUAGE",
                                		description: "Language used in files that will be inspected on copy paste",
                                   		optional: false,
                                       	type: String)
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['CPD_ANALYZER_STATUS', 'Copy paste analyzer result status']
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
