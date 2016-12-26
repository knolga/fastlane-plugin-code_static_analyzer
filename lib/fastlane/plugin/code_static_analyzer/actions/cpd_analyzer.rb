module Fastlane
  module Actions
    module SharedValues
      CPD_ANALYZER_STATUS = :CPD_ANALYZER_STATUS
    end

    class CpdAnalyzerAction < Action
      SUPPORTED_LAN = ['python', 'objectivec', 'jsp', 'ecmascript', 'fortran', 'cpp', 'ruby', 'php', 'java', 'matlab', 'scala', 'plsql', 'go', 'cs']

      def self.run(params)
        UI.header 'Step cpd_analyzer'
        work_dir = params[:work_dir]
        files_to_exclude = params[:files_to_exclude]
        files_to_inspect = params[:files_to_inspect]
        UI.message '[!] Analyzer will be run for all files in work directory'.blue if !files_to_inspect or files_to_inspect.empty?
        if files_to_exclude
          files_to_exclude.each do |file_path|
            UI.user_error!("Unexisted path '#{work_dir}#{file_path}'. Check parameters 'work_dir' and 'files_to_exclude'") unless File.exist?("#{work_dir}#{file_path}")
          end
        end
        if files_to_inspect
          files_to_inspect.each do |file_path|
            UI.user_error!("Unexisted path '#{work_dir}#{file_path}'. Check parameters 'work_dir' and 'files_to_inspect'") unless File.exist?("#{work_dir}#{file_path}")
          end
        end

        FileUtils.mkdir_p("#{work_dir}/#{params[:result_dir]}") unless File.exist?("#{work_dir}/#{params[:result_dir]}")
        temp_result_file = "#{work_dir}/#{params[:result_dir]}/temp_copypaste.xml"
        result_file = "#{work_dir}/#{params[:result_dir]}/codeAnalysResults_cpd.xml"
        tokens = params[:tokens]
        files = Actions::CpdAnalyzerAction.add_root_path(work_dir, files_to_inspect, true)
        lan = params[:language]
        exclude_files = Actions::CpdAnalyzerAction.add_root_path(work_dir, files_to_exclude, false)

        lib_path = File.join(Helper.gem_path('fastlane-plugin-code_static_analyzer'), "lib")
        run_script_path = File.join(lib_path, "assets/cpd_code_analys.sh")

        run_script = "#{run_script_path} '#{temp_result_file}' #{tokens} '#{files}' '#{exclude_files}' '#{lan}'"
        Actions::FormatterAction.cpd_format(tokens, lan, exclude_files, temp_result_file, files)
        FastlaneCore::CommandExecutor.execute(command: run_script.to_s,
                                            print_all: false,
                                            error: proc do |error_output|
                                                     # handle error here
                                                   end)
        status = $?.exitstatus
        xml_content = Actions::JunitParserAction.parse_xml(temp_result_file)
        junit_xml = Actions::JunitParserAction.add_testsuite('copypaste', xml_content)
        # create full file with results
        Actions::JunitParserAction.create_junit_xml(junit_xml, result_file)

        Actions.lane_context[SharedValues::CPD_ANALYZER_STATUS] = status
      end

      def self.add_root_path(root, file_list, is_inspected)
        new_list = ''
        if file_list.nil? || file_list.empty?
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
        "This analyzer detect copy paste code (it uses PMD CPD)"
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
                        env_name: "FL_CPD_ANALYZER_WORK_DIR",
                        description: "Path to work/project directory",
                        optional: false,
                        type: String,
                        verify_block: proc do |value|
                          UI.user_error!("No work directory for CpdAnalyzerAction given, pass using `work_dir` parameter") unless value and !value.empty?
                          UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                        end),
          FastlaneCore::ConfigItem.new(key: :result_dir,
                        env_name: "FL_CPD_ANALYZER_RESULT_DIR",
                        description: "Directory's name for storing  analysis results",
                        optional: true,
                        type: String,
                        default_value: 'artifacts'),
          FastlaneCore::ConfigItem.new(key: :tokens,
                        env_name: "FL_CPD_ANALYZER_TOKENS",
                        description: "The min number of words in code that is detected as copy paste",
                        optional: true,
                        type: String,
                        default_value: '100'),
          FastlaneCore::ConfigItem.new(key: :files_to_inspect,
                        env_name: "FL_CPD_ANALYZER_FILES_TO_INSPECT",
                        description: "List of path (relative to work directory) to files to be inspected on copy paste",
                        optional: true,
                        type: Array,
                        verify_block: proc do |value|
                          value.each do |file_path|
                            UI.user_error!("File at path '#{file_path}' should be relative to work dir and start from '/'") unless file_path.start_with? "/"
                          end
                        end),
          FastlaneCore::ConfigItem.new(key: :files_to_exclude,
                                        env_name: "FL_CPD_ANALYZER_FILES_NOT_TO_INSPECT",
                                        description: "List of path (relative to work directory) to files not to be inspected on copy paste",
                                        optional: true,
                                        type: Array,
                                        verify_block: proc do |value|
                                          value.each do |file_path|
                                            UI.user_error!("File at path '#{file_path}' should be relative to work dir and start from '/'") unless file_path.start_with? "/"
                                          end
                                        end),
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
        platform == :ios
      end
    end
  end
end
