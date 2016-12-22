module Fastlane
  module Actions
    module SharedValues
      ANALYZER_STATUS = :ANALYZER_STATUS
    end
    
    class CodeStaticAnalyzerAction < Action
    
      SUPPORTED_ANALYZER = ["xcodeWar", "rubocop"]
    
      def self.run(params)
       	analyzers = params[:analyzers]
       	analyzers = SUPPORTED_ANALYZER if ((analyzers and analyzers.empty?) or analyzers[0]=='all')
 		ruby_files = params[:ruby_files]
 		xcode_project = params[:xcode_project]
     	analyzers.each do |analyzer|
        case analyzer
  			when 'xcodeWar' 
    	  	  UI.user_error!("No project-workspace name for Warnings Analyzer given. Pass using `xcode_project` or configure analyzers to run using `analyzers`") if ((not xcode_project) or  (xcode_project and xcode_project.empty?))
    	  	when 'rubocop' 
  			  UI.user_error!("No ruby files for Ruby Analyzer given. Pass using `ruby_files` or configure analyzers to run using `analyzers`") if ((not ruby_files) or  (ruby_files and ruby_files.empty?))
    	  	end
        end 
        
        status_cpd = 0
       	status_rubocop = 0
 		status_static = 0
 
       	clear_all_files = "#{params[:root_dir]}/#{params[:result_dir]}/*.*"
       	clear_temp_files = "#{params[:root_dir]}/#{params[:result_dir]}/*temp*.*"
		sh "rm -rf #{clear_all_files}"		
  		# CPD Parser 
        status_cpd = Actions::CpdAnalyzerAction.run(work_dir: params[:root_dir],
      											 result_dir: params[:result_dir],
       											 tokens: params[:cpd_tokens],
       											 language: params[:cpd_language],
       											 files_to_inspect: params[:cpd_files], 
       											 files_to_exclude: params[:cpd_files_to_exclude])
       	analyzers.each do |analyzer|
          case analyzer
  			when 'xcodeWar' 
    	  	  status_static = Actions::WarningAnalyzerAction.run(work_dir: params[:root_dir],
      											 			result_dir: params[:result_dir],
       														project_name: params[:xcode_project])
  			when 'rubocop' 
    	  	  status_rubocop = Actions::RubyAnalyzerAction.run(work_dir: params[:root_dir],
      											 			result_dir: params[:result_dir],
       														files_to_inspect: params[:ruby_files])
  			end
        end
	    sh "rm -rf #{clear_temp_files}"

        if  Actions::CodeStaticAnalyzerAction.status_to_boolean(status_cpd) && 
   			Actions::CodeStaticAnalyzerAction.status_to_boolean(status_static) &&
   			Actions::CodeStaticAnalyzerAction.status_to_boolean(status_rubocop)
            Actions.lane_context[SharedValues::ANALYZER_STATUS] = true
		else
  			Actions.lane_context[SharedValues::ANALYZER_STATUS] = false
		end
      end
      
      def self.status_to_boolean(var)
  		case var
  		when 1, '1'
    	  return false
  		when 0, '0'
    	  return true
  		end
	  end

      def self.description
        "Runs different Static Analyzers and generate report"
      end

      def self.authors
        ["knolga"]
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
            FastlaneCore::ConfigItem.new(key: :analyzers, 
                                   		env_name: "FL_CSA_RUN_ANALYZERS",
                                		description: "List of analysers you want to run.  Supported analyzers: #{SUPPORTED_ANALYZER}",
                                   		optional: false,
                                       	type: Array,
                              			verify_block: proc do |value|
                              			  if ((value and value.empty?) or value[0]=='all')
                              			    UI.message '[!] Will be run all analyzers'.blue 
                              			  else
                                      	    value.each do |run_analyzer|
                                              UI.user_error!("The analyzer '#{run_analyzer}' is not supported.  Supported analyzers: #{SUPPORTED_ANALYZER}") unless SUPPORTED_ANALYZER.include? run_analyzer
                                            end
                                          end
                                      	end),
            FastlaneCore::ConfigItem.new(key: :root_dir, 
                        				env_name: "FL_CSA_WORK_DIR",
                     					description: "Path to project/work directory. In this dir will be found all files for analysis and created results dir",
                        				optional: false,
                            			type: String,
                            		  	verify_block: proc do |value|
                                          UI.user_error!("No work directory given, pass using `root` parameter") unless (value and not value.empty?)
                                          UI.user_error!("Unexisted path '#{value}'") unless File.exist?(value)
                                      	end),    
            FastlaneCore::ConfigItem.new(key: :result_dir,  
                        				env_name: "CSA_RESULT_DIR_NAME",
                     					description: "Directory's name for storing  analysis results",
                        				optional: true,
                            			type: String,
                            			default_value: 'artifacts'),    
            # parameters for CPD analyzer                			
			FastlaneCore::ConfigItem.new(key: :cpd_tokens,
                     					description: "The min number of words in code that is detected as copy paste",
                        				optional: true,
                            			type: String,
                   						default_value: '100'),
			FastlaneCore::ConfigItem.new(key: :cpd_files, 
                     					description: "List of path (relative to work directory) to files to be inspected on copy paste",
                        				optional: true,
                            			type: Array),
			FastlaneCore::ConfigItem.new(key: :cpd_files_to_exclude, 
                                		description: "List of path (relative to work directory) to files not to be inspected on copy paste",
                                   		optional: true,
                                       	type: Array),
            FastlaneCore::ConfigItem.new(key: :cpd_language, 
                                		description: "Language used in files that will be inspected on copy paste",
                                   		optional: false,
                                       	type: String),
            # next parameters are optional, but some of them are required in analyzer if it has to be run
            # parameters for Ruby analyzer                           	
			FastlaneCore::ConfigItem.new(key: :ruby_files, # required in analyzer
                     					description: "List of path (relative to work directory) to ruby files to be inspected on warnings & syntax",
                        				optional: true, 
                            			type: Array),
            # parameters for Warnings analyzer                			
            FastlaneCore::ConfigItem.new(key: :xcode_project, # required in analyzer
                                       description: "Xcode project-workspace name (without extention) in work directory", 
                                       optional: true, 
                            		   type: String)
        ]
      end
      	
	  def self.output
        # Define the shared values you are going to provide
        [
          ['ANALYZER_STATUS', 'Code analysis result (0 - code is clear, any other value - code include warnings/errors/etc.)']
        ]
      end
      
      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
        #
        # [:ios, :mac, :android].include?(platform)
        # true
        platform == :ios
      end
    end
  end
end
