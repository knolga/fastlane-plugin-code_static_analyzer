module Fastlane
  require File.join CodeStaticAnalyzer::ROOT, "assets/formatter.rb"
  require File.join CodeStaticAnalyzer::ROOT, "assets/junit_parser.rb"
  require 'xcodeproj'

  module Actions
    module SharedValues
      ANALYZER_STATUS = :ANALYZER_STATUS
    end

    class CodeStaticAnalyzerAction < Action
      SUPPORTED_ANALYZER = ["xcodeWar", "rubocop", "CPD"]
      RESULT_FILE = 'codeAnalysResults_analyzers.xml'
      attr_accessor :checked_pmd, :checked_xcode_param, :xml_content, :run_main

      def self.run(params)
        @run_main = true
        Actions::CodeStaticAnalyzerAction.is_pmd_installed
        platform = Actions.lane_context[SharedValues::PLATFORM_NAME].to_s
        @xml_content = ''
        root_dir = work_dir
        analyzers = params[:analyzers]
        analyzers = SUPPORTED_ANALYZER if (analyzers and analyzers.empty?) or analyzers[0] == 'all'
        xcode_project = params[:xcode_project_name]
        xcode_workspace = params[:xcode_workspace_name]
        xcode_targets = params[:xcode_targets]
        
        # use additional checks for optional parameters, but required in specific analyzer     
        exclude_junit = params[:disable_junit]
        if exclude_junit
          exclude_junit.each do |exclude_from|
            UI.error "disable_junit parameter is partly skipped: the analyzer '#{exclude_from}' is not supported.  Supported analyzers: #{SUPPORTED_ANALYZER}, 'all'" unless SUPPORTED_ANALYZER.map(&:downcase).include? exclude_from.downcase or exclude_from == 'all'
          end
        exclude_junit = SUPPORTED_ANALYZER  if exclude_junit[0] == 'all'
        end                  
        analyzers.each do |analyzer|
          case analyzer.downcase
          when 'xcodewar'
            UI.user_error!("No project name for Warnings Analyzer given. Pass using `xcode_project` or configure analyzers to run using `analyzers`") if !xcode_project or (xcode_project and xcode_project.empty?) and platform != 'android'
            checked_params = xcode_check_parameters(root_dir, xcode_project, xcode_workspace, xcode_targets)
            xcode_project = checked_params[0]
            xcode_workspace = checked_params[1]
            xcode_targets = checked_params[2]
          end
        end

        status_rubocop = 0
        status_static = 0
        clear_all_files = "#{root_dir}#{params[:result_dir]}/*.*"
        # clear_temp_files = "#{root_dir}#{params[:result_dir]}/*temp*.*"
        sh "rm -rf #{clear_all_files}"

        # Run alyzers
        use_junit = is_include(exclude_junit, "cpd") ? false : true
        status_cpd = Actions::CpdAnalyzerAction.run(
          result_dir: params[:result_dir],
          use_junit_format: use_junit,
          tokens: params[:cpd_tokens],
          language: params[:cpd_language],
          cpd_files_to_inspect: params[:cpd_files_to_inspect],
          cpd_files_to_exclude: params[:cpd_files_to_exclude]
        )
        analyzers.each do |analyzer|
          case analyzer.downcase
          when 'xcodewar'
            use_junit = is_include(exclude_junit, "xcodewar") ? false : true
            if platform != "android"
              status_static = Actions::WarningAnalyzerAction.run(
                result_dir: params[:result_dir],
                xcode_project_name: xcode_project,
                xcode_workspace_name: xcode_workspace,
                xcode_targets: xcode_targets,
                use_junit_format: use_junit
              )
            end
          when 'rubocop'
            use_junit = is_include(exclude_junit, "rubocop") ? false : true
            status_rubocop = Actions::RubyAnalyzerAction.run(
              result_dir: params[:result_dir],
              ruby_files: params[:ruby_files],
              use_junit_format: use_junit
            )
          end
        end
        # sh "rm -rf #{clear_temp_files}"

        create_analyzers_run_result("#{root_dir}#{params[:result_dir]}/")

        if  Actions::CodeStaticAnalyzerAction.status_to_boolean(status_cpd) &&
            Actions::CodeStaticAnalyzerAction.status_to_boolean(status_static) &&
            Actions::CodeStaticAnalyzerAction.status_to_boolean(status_rubocop)
          Actions.lane_context[SharedValues::ANALYZER_STATUS] = true
        else
          Actions.lane_context[SharedValues::ANALYZER_STATUS] = false
        end
      end

      def self.start_xml_content
        @xml_content = ""
      end

      def self.run_from_main_action
        @run_main
      end

      def self.analyzers_xml
        @xml_content
      end

      class << self
        attr_reader :checked_pmd
      end

      def self.checked_xcode
        @checked_xcode_param
      end

      def self.add_xml_content(root, analyzer_name, temp_result_file, info)
        UI.error "#{analyzer_name} analyzer failed to create temporary result file. More info in #{root}#{RESULT_FILE}"
        new_line = JunitParser.xml_level(3)
        if info.empty?
          info = "Don't see #{temp_result_file} file.#{new_line}Try to run command with --verbose" \
  	    " to see warnings made by used analyzers"
        end
        failures = JunitParser.add_failure('', 'unexisted result file', "#{new_line}#{info}")
        @xml_content += JunitParser.add_failed_testcase("#{analyzer_name} analyzer crash", failures)
      end

      def self.create_analyzers_run_result(result_dir)
        unless @xml_content.empty?
          junit_xml = JunitParser.add_testsuite('static anlyzers', @xml_content)
          JunitParser.create_junit_xml(junit_xml, "#{result_dir}/#{RESULT_FILE}")
        end
      end

      def self.status_to_boolean(var)
        if var == 0 or var == '0' or var == true or var == 'true'
          return true
        else
          return false
        end
      end

	  def self.is_include(list, value)
	    if list
	      list = list.map(&:downcase)
	      value = value.downcase
	      return (list.include? value) ? true : false 
	    else
	      return false
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

      def self.work_dir
        directory = Dir.pwd
        directory + "/" unless directory.end_with? "/"
      end

      def self.check_file_exist(work_dir, file, parameter_name)
        if file.kind_of?(Array)
          file.each do |file_path|
            UI.user_error!("Unexisted path '#{work_dir}#{file_path}'. Check '#{parameter_name}' parameter. Files should be relative to work directory '#{work_dir}'") if Dir.glob("#{work_dir}#{file_path}").empty?
          end
        else
          UI.user_error!("Unexisted path '#{work_dir}#{file}'. Check '#{parameter_name}' parameter. Files should be relative to work directory '#{work_dir}'") if Dir.glob("#{work_dir}#{file}").empty?
        end
      end

      def self.add_root_path(root, file_list, is_inspected)
        file_list_str = ''
        if file_list.nil? || file_list.empty?
          file_list_str = "'#{root}'" if is_inspected
        else
          file_list.each do |file|
            file_path = "#{root}#{file}"
            file_path = file_path.sub("//", '/')
            file_path = file_path.sub("/./", '/')
            file_list_str += "'#{file_path}' "
          end
        end
        file_list_str
      end

      def self.xcode_check_parameters(root_dir, project, workspace, targets)
        @checked_xcode_param = false
        if Actions.lane_context[SharedValues::PLATFORM_NAME] == 'android'
          UI.user_error! 'This warning_analyzer not supported for ios platform'
        else
          unless project.empty?
            project += '.xcodeproj' unless project.end_with? '.xcodeproj'
            wrong_path = Dir.glob(root_dir + project).empty?
            UI.user_error! "Wrong project name '#{project}'. Check extension if you use it." if wrong_path
          end

          if workspace and !workspace.empty?
            workspace += '.xcworkspace' unless workspace.end_with? '.xcworkspace'
          else
            workspace = project.gsub(".xcodeproj", '') + '.xcworkspace'
          end
          wrong_path = Dir.glob(root_dir + workspace).empty?
          UI.user_error! "Wrong workspace name '#{workspace}'" if wrong_path

          # check targets
          available_targets = []
          new_targets = []
          project_info = Xcodeproj::Project.open(project.to_s)
          project_info.targets.each do |target|
            available_targets.push(target.name)
          end
          if targets and targets.count > 0
            error = []
            targets.each do |currect_target|
              next if currect_target.tr(' ', '').empty?
              if available_targets.include? currect_target
                new_targets.push(currect_target)
              else
                error.push(currect_target)
              end
            end
            UI.user_error!("The #{error} targets don't exist in project.") unless error.count == 0
          end
          new_targets = available_targets if new_targets.count == 0
          @checked_xcode_param = true
          [project, workspace, new_targets]
        end
      end

      def self.description
        "Runs different Static Analyzers and generate report"
      end

      def self.authors
        ["olgakn"]
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
          FastlaneCore::ConfigItem.new(key: :disable_junit,
                                env_name: "FL_CSA_DISABLED_JUNIT_RESULTS",
                                description: "List of analysers for which you want to disable results in JUnit format.  Supported analyzers: #{SUPPORTED_ANALYZER}, 'all'",
                                optional: true,
                                type: Array),
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
          FastlaneCore::ConfigItem.new(key: :cpd_files_to_inspect,
                                   description: "List of files and directories (relative to work directory) to inspect on copy paste",
                                   optional: true,
                                   type: Array),
          FastlaneCore::ConfigItem.new(key: :cpd_files_to_exclude,
                                    description: "List of files and directories (relative to work directory) not to inspect on copy paste",
                                    optional: true,
                                    type: Array),
          FastlaneCore::ConfigItem.new(key: :cpd_language,
                                  description: "Language used in files that will be inspected on copy paste.\nSupported analyzers: #{Actions::CpdAnalyzerAction::SUPPORTED_LAN} or don't set if you need any other language",
                                  optional: true,
                                  type: String,
                                  verify_block: proc do |value|
                                    UI.user_error!("Language '#{value}' is not supported.\nSupported languages: #{Actions::CpdAnalyzerAction::SUPPORTED_LAN} or empty if you need any other language") unless Actions::CpdAnalyzerAction::SUPPORTED_LAN.map(&:downcase).include? value.downcase or value.empty? or !value
                                  end),
          # parameters for Ruby analyzer
          FastlaneCore::ConfigItem.new(key: :ruby_files,
                                   description: "List of path (relative to work directory) to ruby files to be inspected on warnings & syntax",
                                   optional: true,
                                   type: Array),
          # parameters for Warnings analyzer
          FastlaneCore::ConfigItem.new(key: :xcode_project_name, # required in analyzer
                                 description: "Xcode project name in work directory",
                                 optional: true,
                                 type: String),
          FastlaneCore::ConfigItem.new(key: :xcode_workspace_name,
                                 description: "Xcode workspace name in work directory",
                                 optional: true,
                                 type: String),
          FastlaneCore::ConfigItem.new(key: :xcode_targets,
                                 description: "List of Xcode targets to inspect",
                                optional: true,
                                type: Array)
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
