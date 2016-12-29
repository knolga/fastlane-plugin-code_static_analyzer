module Fastlane
  module Actions
    module SharedValues
      ANALYZER_STATUS = :ANALYZER_STATUS
    end

    class CodeStaticAnalyzerAction < Action
      SUPPORTED_ANALYZER = ["xcodeWar", "rubocop", "CPD"]
	   attr_accessor :checked_pmd
  
      def self.run(params)
        Actions::CodeStaticAnalyzerAction.is_pmd_installed
        platform = Actions.lane_context[SharedValues::PLATFORM_NAME].to_s
        root_dir = get_work_dir
        analyzers = params[:analyzers]
        analyzers = SUPPORTED_ANALYZER if (analyzers and analyzers.empty?) or analyzers[0] == 'all'
        ruby_files = params[:ruby_files]
        xcode_project = params[:xcode_project_name]
        
        # use additional checks for optional parameters, but required in specific analyzer
        analyzers.each do |analyzer|
          case analyzer
          when 'xcodeWar'
            UI.user_error!("No project name for Warnings Analyzer given. Pass using `xcode_project` or configure analyzers to run using `analyzers`") if !xcode_project or (xcode_project and xcode_project.empty?) and platform!='android'
          end
        end
        
        status_rubocop = 0
        status_static = 0
        clear_all_files = "#{root_dir}#{params[:result_dir]}/*.*"
        clear_temp_files = "#{root_dir}#{params[:result_dir]}/*temp*.*"
        sh "rm -rf #{clear_all_files}"
        
        # Run alyzers
        status_cpd = Actions::CpdAnalyzerAction.run(
                              result_dir: params[:result_dir],
                              tokens: params[:cpd_tokens],
                              language: params[:cpd_language],
                              cpd_files_to_inspect: params[:cpd_files_to_inspect],
                              cpd_files_to_exclude: params[:cpd_files_to_exclude])
        analyzers.each do |analyzer|
          case analyzer
          when 'xcodeWar'
	        if platform!="android"
              status_static = Actions::WarningAnalyzerAction.run(
                                    result_dir: params[:result_dir],
                                    xcode_project_name: params[:xcode_project_name],
                                    xcode_workspace_name: params[:xcode_workspace_name]) 
            end
          when 'rubocop'
            status_rubocop = Actions::RubyAnalyzerAction.run(
                                    result_dir: params[:result_dir],
                                    ruby_files: params[:ruby_files])
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

      def self.methodA
        @checked_pmd
      end
  
      def self.status_to_boolean(var)
        case var
        when 1, '1'
          return false
        when 0, '0'
          return true
        end
      end

      def self.is_pmd_installed
        @checked_pmd = false
        begin
     	  Actions.sh('type pmd')
     	rescue
     	  UI.user_error! 'PMD not installed. Please, install PMD for using copy paste analyzer.'
     	end
     	@checked_pmd = true
      end

	  def self.get_work_dir
	    directory = Dir.pwd
        directory = directory + "/" unless directory.end_with? "/"
	  end
	  
	  def self.check_file_exist(work_dir, file, parameter_name)
	    if file.kind_of?(Array)
	      file.each do |file_path|
            UI.user_error!("Unexisted path '#{work_dir}#{file_path}'. Check '#{parameter_name}' parameter. Files should be relative to work directory '#{work_dir}'") unless !Dir.glob("#{work_dir}#{file_path}").empty?
          end
	    else
	      UI.user_error!("Unexisted path '#{work_dir}#{file}'. Check '#{parameter_name}' parameter. Files should be relative to work directory '#{work_dir}'") unless !Dir.glob("#{work_dir}#{file}").empty?
	    end
	  end
	
	  def self.add_root_path(root, file_list, is_inspected)
        file_list_str = ''
        if file_list.nil? || file_list.empty?
          file_list_str = "#{root}" if is_inspected
        else
          file_list.each do |file|
            file_list_str += "#{root}#{file} "
          end
        end
        file_list_str
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
        "This plugins is the helper for checking code on warnings, copypaste, syntax, etc.\n" \
        "Each analyzer in this plugin save result status in shared values <NAME>_ANALYZER_STATUS: 0 - code is clear, any other value - code include warnings/errors.\n" \
        "Also each analyzer save results in separate file: codeAnalysResult_<name of analyzer>.xml"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :analyzers,
                                env_name: "FL_CSA_RUN_ANALYZERS",
                                description: "List of analysers you want to run.  Supported analyzers: #{SUPPORTED_ANALYZER}",
                                optional: false,
                                type: Array,
                                verify_block: proc do |value|
                                  UI.message '[!] Will be run all analyzers'.blue if (value and value.empty?) or value[0] == 'all'
                                  value.each do |run_analyzer|
                                    UI.user_error!("The analyzer '#{run_analyzer}' is not supported.  Supported analyzers: #{SUPPORTED_ANALYZER}, 'all'") unless SUPPORTED_ANALYZER.map(&:downcase).include? run_analyzer.downcase or run_analyzer == 'all'
                                  end
                                end),
          FastlaneCore::ConfigItem.new(key: :result_dir,
                              env_name: "CSA_RESULT_DIR_NAME",
                              description: "[optional] Directory's name for storing  analysis results",
                              optional: true,
                              type: String,
                              default_value: 'artifacts'),
          # parameters for CPD analyzer
          FastlaneCore::ConfigItem.new(key: :cpd_tokens,
                                   description: "[optional] The min number of words in code that is detected as copy paste",
                                   optional: true,
                                   type: String,
                                   default_value: '100'),
          FastlaneCore::ConfigItem.new(key: :cpd_files_to_inspect,
                                   description: "[optional] List of path (relative to work directory) to files to be inspected on copy paste",
                                   optional: true,
                                   type: Array),
          FastlaneCore::ConfigItem.new(key: :cpd_files_to_exclude,
                                    description: "[optional] List of path (relative to work directory) to files not to be inspected on copy paste",
                                    optional: true,
                                    type: Array),
          FastlaneCore::ConfigItem.new(key: :cpd_language,
                                  description: "[optional] Language used in files that will be inspected on copy paste.\nSupported analyzers: #{Actions::CpdAnalyzerAction::SUPPORTED_LAN} or don't set if you need any other language",
                                  optional: true,
                                  type: String,
                                  verify_block: proc do |value|
                                    UI.user_error!("Language '#{value}' is not supported.\nSupported languages: #{Actions::CpdAnalyzerAction::SUPPORTED_LAN} or empty if you need any other language") unless Actions::CpdAnalyzerAction::SUPPORTED_LAN.map(&:downcase).include? value.downcase or value.empty? or not value
                                  end),
          # next parameters are optional, but some of them are required in analyzer if it has to be run
          # parameters for Ruby analyzer
          FastlaneCore::ConfigItem.new(key: :ruby_files, 
                                   description: "[optional] List of path (relative to work directory) to ruby files to be inspected on warnings & syntax",
                                   optional: true,
                                   type: Array),
          # parameters for Warnings analyzer
          FastlaneCore::ConfigItem.new(key: :xcode_project_name, # required in analyzer
                                 description: "[optional] Xcode project name in work directory",
                                 optional: true,
                                 type: String,
                                 verify_block: proc do |value|
                                   UI.user_error!("Wrong project extention '#{value}'. Need to be 'xcodeproj'") unless value.end_with? '.xcodeproj' and !value.empty? and Actions.lane_context[SharedValues::PLATFORM_NAME]!='android'
                                 end),
          FastlaneCore::ConfigItem.new(key: :xcode_workspace_name,
                                 description: "[optional] Xcode workspace name in work directory",
                                 optional: true,
                                 type: String,
                                 verify_block: proc do |value|
                                   UI.user_error!("Wrong workspace extention '#{value}'. Need to be 'xcworkspace'") unless value.end_with? '.xcworkspace' and !value.empty? and Actions.lane_context[SharedValues::PLATFORM_NAME]!='android'
                                 end)
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
         true
      end
    end
  end
end
