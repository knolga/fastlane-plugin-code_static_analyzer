module Fastlane
  module Actions
    class CodeStaticAnalyzerAction < Action
      
      def self.run(params)
       	UI.important 'run from local'
       	UI.important "analyzers -> #{params[:analyzers]}"
       	UI.important "cpd_files -> #{params[:cpd_files]}"
       	UI.important "tokens -> #{params[:tokens]}"
       	UI.important "root -> #{params[:root]}"
		UI.important "cpd_files_to_exclude -> #{params[:cpd_files_to_exclude]}"
       	UI.important "language -> #{params[:language]}"
       	
       	clear_files = "#{params[:root]}/params[:result]/*.*"
		sh "rm -rf #{clear_files}"
				
  		# CPD Parser
     #   status_cpd = Actions::CpdAnalyzerAction.run(work_dir: params[:root],
     # 											 result_dir: params[:result],
     #  												tokens:	params[:tokens],
     #  												files_to_inspect:	params[:cpd_files], 
     #  												language:	params[:language],
     #  												files_to_exclude:	params[:cpd_files_to_exclude])
 status_rubocop=''
       	params[:analyzers].each do |analyzer|
          case analyzer
  			when 'xcodeWar' 
    	  	  UI.success 'run xcode analyzer'
    	  	  UI.success 'create xcode analyzer testsuite'
  			when 'rubocop' 
    	  	  UI.success 'run rubocop analyzer'
    	  	  status_rubocop = Actions::RubyAnalyzerAction.run(work_dir: params[:root],
      											 result_dir: params[:result],
       												files_to_inspect:	params[:ruby_files])
  			end
        end
UI.error "result = #{status_rubocop}"
#        if  Actions::CodeStaticAnalyzerAction.status_to_boolean(status_cpd) #&& status_static
#   			#status_to_boolean(status_cpd) &&
#   #status_to_boolean(status_rubocop)
#  			UI.success 'Success. New builds can be prepared. OLGA test'
#            exit 0
#		else
#  			UI.error 'Failed. New builds deprecated. Warnings (see more in *.xml files) OLGA test'
#  			exit 1
#		end

##TODO: delete files *temp*.xml
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
                        				env_name: "CSA_WORK_DIR",
                     					description: "Path to project/work directory. In this dir will be founded all files for analysis and created results dir",
                        				optional: false,
                            			type: String),    
        FastlaneCore::ConfigItem.new(key: :result,  #insert check block if path exist and string ends by /
                        				env_name: "CSA_RESULT_DIR_NAME",
                     					description: "???",
                        				optional: true,
                            			type: String,
                            			default_value: 'artifacts'),    
			FastlaneCore::ConfigItem.new(key: :tokens,
                     					description: "The min number of words in code that is detected as copy paste",
                        				optional: true,
                            			type: String,
                   						default_value: '100'),
			FastlaneCore::ConfigItem.new(key: :cpd_files, 
                     					description: "Path to dir/file to be inspected on copy paste",
                        				optional: true,
                            			type: Array),
			FastlaneCore::ConfigItem.new(key: :cpd_files_to_exclude, 
                                		description: "Path to dir/file not to be inspected on copy paste",
                                   		optional: true,
                                       	type: Array),
            FastlaneCore::ConfigItem.new(key: :language, 
                                		description: "Language used in files that will be inspected on copy paste",
                                   		optional: false,
                                       	type: String),
                                       	
			FastlaneCore::ConfigItem.new(key: :ruby_files, 
                     					description: "Path to ruby file to be inspected on warnings & syntax",
                        				optional: true, #optional because this analyzer we run only if required
                            			type: Array)
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
