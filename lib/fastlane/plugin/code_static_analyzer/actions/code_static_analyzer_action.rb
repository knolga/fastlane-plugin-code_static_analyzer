module Fastlane
  module Actions
    class CodeStaticAnalyzerAction < Action
    #  SRCROOT = './artifacts/'
      status_static=''
      
      def self.run(params)
       	UI.important 'run from local'
       	UI.error params[:root]

       	
       	junit_xml = ''
		
		clear_files = "#{params[:root]}*.*"
		sh "rm -rf #{clear_files}"
		
		# CPD Parser

		xml_content = Actions::CodeStaticAnalyzerAction.CPD_analyzer("#{params[:root]}copypaste.xml",100,'.','objectivec',['./Pods', './ThirdParty/'])
        junit_xml += Actions::JunitParserAction.add_testsuite('1', 'copypaste', xml_content)
        
        if Actions::CodeStaticAnalyzerAction.status_to_boolean(xml_content) #&& status_static
   			#status_to_boolean(status_cpd) &&
   #status_to_boolean(status_rubocop)
  			UI.success 'Success. New builds can be prepared.'
  			 Actions.lane_context[SharedValues::ANALYZER_STATUS] = 0
            #exit 0
		else
  			UI.error 'Failed. New builds deprecated. Warnings (see more in *.xml files)'
  			 Actions.lane_context[SharedValues::ANALYZER_STATUS] = 1
  			#exit 1
		end
       	UI.important 'run from'
       	UI.error File.dirname(__FILE__)
        
        
        # create full file with results
		Actions::JunitParserAction.create_code_analysis_junit_xml(junit_xml, "#{params[:root]}codeAnalysResults")
 #Actions.lane_context[SharedValues::ANALYZER_STATUS] = 0
      end
      
      def self.CPD_analyzer(filepathname, tokens, files, lan, files_to_exclude)
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
       status_cpd = $?.exitstatus
       Actions::JunitParserAction.parse_xml_to_xml( filepathname)
      end
      
      def self.status_to_boolean(var)
  		case var
  		when 1, '1' # true,'true',
    	  return false
  		when 0, '0' # false, 'false',
    	  return true
  		end
	  end

      def self.description
        "Runs different Static Analyzers and generate report"
      end

      def self.authors
        ["Olga Kniazska"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "This plugins is the helper for checking code on warnings, copypaste, syntax, etc."
      end

      def self.available_options
        [
           FastlaneCore::ConfigItem.new(key: :root,
                                   env_name: "CSA_SRCROOT",
                                description: "A description of your option",
                                   optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
