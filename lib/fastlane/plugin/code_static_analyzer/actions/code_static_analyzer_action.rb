module Fastlane
  module Actions
    class CodeStaticAnalyzerAction < Action
    #  SRCROOT = './artifacts/'
      status_static=''
      
      def self.run(params)
       	UI.important 'run from local'
       	UI.important "analyzers -> #{params[:analyzers]}"
       	UI.important "cpd_files -> #{params[:cpd_files]}"
       	UI.important "tokens -> #{params[:tokens]}"
       	UI.important "root -> #{params[:root]}"
		UI.important "cpd_files_to_exclude -> #{params[:cpd_files_to_exclude]}"
       	UI.important "language -> #{params[:language]}"
       	
       status_cpd = Actions::CpdAnalyzerAction.run(dir: params[:root],
       												tokens:	params[:tokens],
       												files_to_inspect:	params[:cpd_files], 
       												language:	params[:language],
       												files_to_exclude:	params[:cpd_files_to_exclude])
 UI.error "result=#{status_cpd}"
       	params[:analyzers].each do |analyzer|
          case analyzer
  			when 'xcodeWar' 
    	  	  UI.success 'run xcode analyzer'
    	  	  UI.success 'create xcode analyzer testsuite'
  			when 'rubocop' 
    	  	  UI.success 'run rubocop analyzer'
    	  	  UI.success 'create rubocop analyzer testsuite'
  			end
        end
  #     	junit_xml = ''
#		
#		clear_files = "#{params[:root]}*.*"
#		sh "rm -rf #{clear_files}"
#		
#		# CPD Parser
#
#		xml_content = Actions::CodeStaticAnalyzerAction.CPD_analyzer("#{params[:root]}copypaste.xml",100,'.','objectivec',['./Pods', './ThirdParty/'])
  #      junit_xml += Actions::JunitParserAction.add_testsuite('1', 'copypaste', xml_content)
  #      
  #      
  #      
  #      # create full file with results
#		Actions::JunitParserAction.create_code_analysis_junit_xml(junit_xml, "#{params[:root]}codeAnalysResults")
#
#        if  Actions::CodeStaticAnalyzerAction.status_to_boolean(status_cpd) #&& status_static
#   			#status_to_boolean(status_cpd) &&
#   #status_to_boolean(status_rubocop)
#  			UI.success 'Success. New builds can be prepared. OLGA test'
#            exit 0
#		else
#  			UI.error 'Failed. New builds deprecated. Warnings (see more in *.xml files) OLGA test'
#  			exit 1
#		end
 #Actions.lane_context[SharedValues::ANALYZER_STATUS] = 0
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
        [#FIXME: add check if it is array, else run message that will be used all analysers and use default value
            FastlaneCore::ConfigItem.new(key: :analyzers, 
                                   		env_name: "CSA_RUN_ANALYZERS",
                                		description: "List of analysers you want to run",
                                   		optional: true,
                                       	type: Array,
                              			default_value: ["rubocop","xcodeWar"]),
            FastlaneCore::ConfigItem.new(key: :root,  #insert check block if path exist and string ends by /
                        				env_name: "CSA_RESULT_DIR",
                     					description: "Path to result directory",
                        				optional: true,
                            			type: String,
                   						default_value: './artifacts/'),    
			FastlaneCore::ConfigItem.new(key: :tokens,
                        				#env_name: "CSA_CPD_TOKENS",
                     					description: "The min number of words in code that is detected as copy paste",
                        				optional: true,
                            			type: String,
                   						default_value: '100'),
			FastlaneCore::ConfigItem.new(key: :cpd_files, 
                        				#env_name: "CSA_CPD_FILES_TO_INSPECT",
                     					description: "Path to dir/file to be inspected on copy paste",
                        				optional: false,
                            			type: String),
			FastlaneCore::ConfigItem.new(key: :cpd_files_to_exclude, 
                                   		#env_name: "CSA_CPD_FILES_NOT_TO_INSPECT",
                                		description: "Path to dir/file not to be inspected on copy paste",
                                   		optional: false,
                                       	type: Array),
            FastlaneCore::ConfigItem.new(key: :language, 
                                   		#env_name: "CSA_CPD_FILE_LANGUAGE",
                                		description: "Language used in files that will be inspected on copy paste",
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
