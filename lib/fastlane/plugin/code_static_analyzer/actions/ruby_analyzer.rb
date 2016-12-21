module Fastlane
  module Actions
    module SharedValues
      RUBY_ANALYZER_STATUS = :RUBY_ANALYZER_STATUS
    end

    class RubyAnalyzerAction < Action
      def self.run(params)
        UI.header('Check Ruby files')
        temp_result_file = "#{params[:work_dir]}/#{params[:result_dir]}/temp_ruby.json"
        result_file = "#{params[:work_dir]}/#{params[:result_dir]}/codeAnalysResults_ruby.xml"
     	files = Actions::CpdAnalyzerAction.add_root_path(params[:work_dir], params[:files_to_inspect], true) 
		run_script = "bundle exec rubocop -f j #{files} > #{temp_result_file}" 

    	FastlaneCore::CommandExecutor.execute(command: "#{run_script}",
                               			     print_all: false,
                                   			 error: proc do |error_output|
                                     				# handle error here
                                   			end)
    	status = $?.exitstatus
    	xml_content = Actions::JunitParserAction.parse_json_to_xml(temp_result_file)
		junit_xml = Actions::JunitParserAction.add_testsuite('', 'rubocop', xml_content)
        # create full file with results
		Actions::JunitParserAction.create_code_analysis_junit_xml(junit_xml, result_file)
		
        Actions.lane_context[SharedValues::RUBY_ANALYZER_STATUS] = status
      end

     def self.add_root_path(root, file_list, is_inspected)
	    new_list = ''
        file_list.each do |file|
	    	new_list += "#{root}#{file} "
	    end
	    new_list
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
           FastlaneCore::ConfigItem.new(key: :work_dir, 
                     				  	description: "Path to work/project directory",
                        			  	optional: false,
                            		  	type: String,
                            		  	verify_block: proc do |value|
                                          UI.user_error!("No parser_action for JunitParserAction given, pass using `work_dir` parameter") unless (value and not value.empty?)
                                          UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                                      	end),    
            FastlaneCore::ConfigItem.new(key: :result_dir,  
                     					description: "Directory's name for storing  analysis results",
                        				optional: true,
                            			type: String,
                            			default_value: 'artifacts'),
			FastlaneCore::ConfigItem.new(key: :files_to_inspect,  
                        				env_name: "FL_RUBY_ANALYZER_FILES_TO_INSPECT",
                     					description: "Path (relative to work directory) to file to be inspected on copy paste",
                        				optional: false,
                            			type: Array,
                            			verify_block: proc do |value|
                                          UI.user_error!("No parser_action for JunitParserAction given, pass using `work_dir` parameter") unless (value and not value.empty?)
                                          value.each do |file_path|
                                            UI.user_error!("File at path '#{file_path}' should be relative to work dir and start from '/'") unless file_path.include? "/"
                                          end
                                      	end)
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['RUBY_ANALYZER_STATUS', 'Copy paste analyzer result status']
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