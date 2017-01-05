module Fastlane
  module Actions
    module SharedValues
      RUBY_ANALYZER_STATUS = :RUBY_ANALYZER_STATUS
    end

    class RubyAnalyzerAction < Action
      def self.run(params)
        UI.header 'Ruby analyzer' if Actions::CodeStaticAnalyzerAction.run_from_main_action
        work_dir = Actions::CodeStaticAnalyzerAction.work_dir

        # checking files for analysing
        files_to_inspect = params[:ruby_files]

        UI.message '[!] Ruby analyzer will be run for all ruby files in work directory'.blue if !files_to_inspect or files_to_inspect.empty?
        Actions::CodeStaticAnalyzerAction.check_file_exist(work_dir, files_to_inspect, 'ruby_files')

        # prepare script and metadata for saving results
        result_dir_path = "#{work_dir}#{params[:result_dir]}"
        FileUtils.mkdir_p(result_dir_path) unless File.exist?(result_dir_path)
        temp_result_file = "#{result_dir_path}/temp_ruby.json"
        result_file = "#{result_dir_path}/codeAnalysResults_ruby.xml"
        files = Actions::CodeStaticAnalyzerAction.add_root_path(work_dir, files_to_inspect, true)
        run_script = "bundle exec rubocop -f j -a #{files}"
        run_script_path = File.join CodeStaticAnalyzer::ROOT, "assets/run_script.sh"
        run_script = "bundle exec #{run_script_path} \"#{run_script}\" '#{temp_result_file}'"
        # use analyzer
        FastlaneCore::CommandExecutor.execute(command: run_script.to_s,
                                            print_all: false,
                                            error: proc do |error_output|
                                                     # handle error here
                                                   end)
        status = $?.exitstatus
        # prepare results
        if Dir.glob(temp_result_file).empty?
          info = (status == 2) ? 'Rubocop return 2: terminates abnormally due to invalid configuration, invalid CLI options, or an internal error' : ''
          Actions::CodeStaticAnalyzerAction.start_xml_content unless Actions::CodeStaticAnalyzerAction.run_from_main_action
          Actions::CodeStaticAnalyzerAction.add_xml_content("#{result_dir_path}/", 'Ruby', temp_result_file, info)
          Actions::CodeStaticAnalyzerAction.create_analyzers_run_result("#{result_dir_path}/") unless Actions::CodeStaticAnalyzerAction.run_from_main_action
          status = 43
        else
          status = 0 if File.read(temp_result_file).empty?
          xml_content = JunitParser.parse_json(temp_result_file)
          junit_xml = JunitParser.add_testsuite('rubocop', xml_content)
          JunitParser.create_junit_xml(junit_xml, result_file)
        end
        Actions.lane_context[SharedValues::RUBY_ANALYZER_STATUS] = status
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "This analyzer detect warnings, errors and check syntax in ruby files. This is based on rubocop"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        # "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports.

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(key: :result_dir,
                        env_name: "FL_RUBY_ANALYZER_RESULT_DIR",
                        description: "[optional] Directory's name for storing  analysis results",
                        optional: true,
                        type: String,
                        default_value: 'artifacts'),
          FastlaneCore::ConfigItem.new(key: :ruby_files,
                        env_name: "FL_RUBY_ANALYZER_FILES_TO_INSPECT",
                        description: "[optional] List of path (relative to work directory) to ruby files to be inspected",
                        optional: true,
                        type: Array)
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        [
          ['RUBY_ANALYZER_STATUS', 'Ruby analyzer result status (0 - success, any other value - failed)']
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
        # you can do things like
        #
        #  true
        #
        #  platform == :ios
        #
        #  [:ios, :mac].include?(platform)
        #
        true
      end
    end
  end
end
