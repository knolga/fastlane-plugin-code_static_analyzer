module Fastlane
  module Actions
    module SharedValues
      CPD_ANALYZER_STATUS = :CPD_ANALYZER_STATUS
    end
    
    require File.join Helper.gem_path('fastlane-plugin-code_static_analyzer'), 'lib/assets/formatter.rb'
    require File.join Helper.gem_path('fastlane-plugin-code_static_analyzer'), 'lib/assets/junit_parser.rb'

    class CpdAnalyzerAction < Action
      SUPPORTED_LAN = ['python', 'objectivec', 'jsp', 'ecmascript', 'fortran', 'cpp', 'ruby', 'php', 'java', 'matlab', 'scala', 'plsql', 'go', 'cs']

      def self.run(params)
        UI.header 'Step cpd_analyzer'  
        work_dir = Actions::CodeStaticAnalyzerAction.get_work_dir 
        
        # checking files for analysing 
        files_to_exclude = params[:cpd_files_to_exclude]
        files_to_inspect = params[:cpd_files_to_inspect]
        UI.message '[!] CPD analyzer will be run for all files in work directory'.blue if !files_to_inspect or files_to_inspect.empty?
        Actions::CodeStaticAnalyzerAction.check_file_exist(work_dir, files_to_exclude, 'cpd_files_to_exclude') if files_to_exclude
        Actions::CodeStaticAnalyzerAction.check_file_exist(work_dir, files_to_inspect, 'cpd_files_to_inspect') if files_to_inspect
       
        # prepare script and metadata for saving results
        result_dir_path = "#{work_dir}#{params[:result_dir]}"
        FileUtils.mkdir_p(result_dir_path) unless File.exist?(result_dir_path)
        temp_result_file = "#{result_dir_path}/temp_copypaste.xml"
        result_file = "#{result_dir_path}/codeAnalysResults_cpd.xml"
        tokens = params[:tokens]
        files = Actions::CodeStaticAnalyzerAction.add_root_path(work_dir, files_to_inspect, true) #CpdAnalyzerAction
        lan = params[:language]
        exclude_files = Actions::CodeStaticAnalyzerAction.add_root_path(work_dir, files_to_exclude, false)#CpdAnalyzerAction

        lib_path = File.join(Helper.gem_path('fastlane-plugin-code_static_analyzer'), "lib")
        run_script_path = File.join(lib_path, "assets/cpd_code_analys.sh")
        run_script = "bundle exec #{run_script_path} '#{temp_result_file}' #{tokens} '#{files}' '#{exclude_files}' '#{lan}'"
        
        # use analyzer
        Formatter.cpd_format(tokens, lan, exclude_files, temp_result_file, files)
        FastlaneCore::CommandExecutor.execute(command: run_script.to_s,
                                            print_all: false,
                                            error: proc do |error_output|
                                                     # handle error here
                                                   end)
        status = $?.exitstatus
        # prepare results
        xml_content = JunitParser.parse_xml(temp_result_file)
        junit_xml = JunitParser.add_testsuite('copypaste', xml_content)
        JunitParser.create_junit_xml(junit_xml, result_file)

        Actions.lane_context[SharedValues::CPD_ANALYZER_STATUS] = status
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "This analyzer detect copy paste code (it uses PMD CPD)"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        #"You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports.
        [
          FastlaneCore::ConfigItem.new(key: :result_dir,
                        env_name: "FL_CPD_ANALYZER_RESULT_DIR",
                        description: "[optional] Directory's name for storing  analysis results",
                        optional: true,
                        type: String,
                        default_value: 'artifacts'),
          FastlaneCore::ConfigItem.new(key: :tokens,
                        env_name: "FL_CPD_ANALYZER_TOKENS",
                        description: "[optional] The min number of words in code that is detected as copy paste",
                        optional: true,
                        type: String,
                        default_value: '100'),
          FastlaneCore::ConfigItem.new(key: :cpd_files_to_inspect,
                        env_name: "FL_CPD_ANALYZER_FILES_TO_INSPECT",
                        description: "[optional] List of path (relative to work directory) to files to be inspected on copy paste",
                        optional: true,
                        type: Array),
          FastlaneCore::ConfigItem.new(key: :cpd_files_to_exclude,
                        env_name: "FL_CPD_ANALYZER_FILES_NOT_TO_INSPECT",
                        description: "[optional] List of path (relative to work directory) to files not to be inspected on copy paste",
                        optional: true,
                        type: Array),
          FastlaneCore::ConfigItem.new(key: :language,
                        env_name: "FL_CPD_ANALYZER_FILE_LANGUAGE",
                        description: "Language used in files that will be inspected on copy paste.  Supported analyzers: #{SUPPORTED_LAN}",
                        optional: false,
                        type: String,
                        verify_block: proc do |value|
                          UI.user_error!("No language for CpdAnalyzerAction given, pass using `language` parameter") unless value and !value.empty?
                          UI.user_error!("This language is not supported.  Supported languages: #{SUPPORTED_LAN}") unless SUPPORTED_LAN.include? value
                        end)
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        [
          ['CPD_ANALYZER_STATUS', 'Copy paste analyzer result status (0 - success, any other value - failed)']
        ]
      end

      def self.return_value
        # If you method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["knolga"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
