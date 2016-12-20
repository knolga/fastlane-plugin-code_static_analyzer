module Fastlane
  module Actions
    module SharedValues
      CPD_ANALYZER_STATUS = :CPD_ANALYZER_STATUS
    end

    class CpdAnalyzerAction < Action
      def self.run(params)
        UI.header('Run copy-paste detector')
        temp_result_file = "#{params[:work_dir]}/#{params[:result_dir]}/temp_copypaste.xml"
        result_file = "#{params[:work_dir]}/#{params[:result_dir]}/codeAnalysResults_cpd.xml"
        tokens = params[:tokens]
          files = Actions::CpdAnalyzerAction.add_root_path(params[:work_dir], params[:files_to_inspect], true) 
        lan = params[:language]
        files_to_exclude = Actions::CpdAnalyzerAction.add_root_path(params[:work_dir], params[:files_to_exclude], false)   
        
        lib_path = File.join(Helper.gem_path('fastlane-plugin-code_static_analyzer'), "lib")
        run_script_path = File.join(lib_path, "assets/cpd_code_analys.sh")

    	run_script = "#{run_script_path} '#{temp_result_file}' #{tokens} '#{files}' '#{files_to_exclude}' '#{lan}'"
    	Actions::FormatterAction.cpd_format(tokens,lan,files_to_exclude,temp_result_file,files )
    	FastlaneCore::CommandExecutor.execute(command: "#{run_script}",
                               			     print_all: false,
                                   			 error: proc do |error_output|
                                     				# handle error here
                                   			end)
    	status = $?.exitstatus
    	xml_content = Actions::JunitParserAction.parse_xml_to_xml(temp_result_file)
		junit_xml = Actions::JunitParserAction.add_testsuite('', 'copypaste', xml_content)
        # create full file with results
		Actions::JunitParserAction.create_code_analysis_junit_xml(junit_xml, result_file)
		
        Actions.lane_context[SharedValues::CPD_ANALYZER_STATUS] = status
      end

	  def self.add_root_path(root, file_list, is_inspected)
	    new_list = ''
	    if file_list==nil || file_list.empty?
          new_list = "#{root}/" if is_inspected
        else
          file_list.each do |file|
	    	  new_list += "#{root}#{file} "
	      end
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
			FastlaneCore::ConfigItem.new(key: :tokens,
                        				env_name: "CPD_TOKENS",
                     					description: "The min number of words in code that is detected as copy paste",
                        				optional: true,
                            			type: String,
                   						default_value: '100'),
			FastlaneCore::ConfigItem.new(key: :files_to_inspect,  
                        				env_name: "CPD_FILES_TO_INSPECT",
                     					description: "Path (relative to work directory) to file to be inspected on copy paste",
                        				optional: true,
                            			type: Array,
                            			verify_block: proc do |value|
                                          UI.user_error!("No parser_action for JunitParserAction given, pass using `work_dir` parameter") unless (value and not value.empty?)
                                          value.each do |file_path|
                                            UI.user_error!("File at path '#{file_path}' should be relative to work dir and start from '/'") unless file_path.include? "/"
                                          end
                                      	end),
			FastlaneCore::ConfigItem.new(key: :files_to_exclude, 
                                   		env_name: "CPD_FILES_NOT_TO_INSPECT",
                                		description: "Path (relative to work directory) to file not to be inspected on copy paste",
                                   		optional: true,
                                       	type: Array,
                                       	verify_block: proc do |value|
                                          UI.user_error!("No parser_action for JunitParserAction given, pass using `work_dir` parameter") unless (value and not value.empty?)
                                          value.each do |file_path|
                                            UI.user_error!("File at path '#{file_path}' should be relative to work dir and start from '/'") unless file_path.include? "/"
                                          end
                                      	end),
            FastlaneCore::ConfigItem.new(key: :language, 
                                   		env_name: "CPD_FILE_LANGUAGE",
                                		description: "Language used in files that will be inspected on copy paste",
                                   		optional: false,
                                       	type: String)
        ]
      end

      def self.output
        # Define the shared values you are going to provide
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
        platform == :ios
      end
    end
  end
end
