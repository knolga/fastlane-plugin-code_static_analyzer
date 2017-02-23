module Fastlane
  module Actions
    module SharedValues
      CLANG_ANALYZER_STATUS = :CLANG_ANALYZER_STATUS
    end

    class ClangAnalyzerAction < Action
      SUPPORTED_STYLE = ['LLVM', 'Google', 'Chromium', 'Mozilla', 'WebKit', 'custom']

      def self.run(params)
        UI.header 'Clang analyzer' if Actions::CodeStaticAnalyzerAction.run_from_main_action
        Actions::CodeStaticAnalyzerAction.is_installed('clang-format', 'clang format analyzer') unless Actions::CodeStaticAnalyzerAction.checked_pmd
        work_dir = Actions::CodeStaticAnalyzerAction.work_dir
        style = params[:basic_style]
        autofix = params[:autocorrect]
        # checking files for analysing
        files_extentions = params[:files_extention]
        files_to_exclude = params[:clang_dir_to_exclude] # TODO: add check
        files_to_inspect = params[:clang_dir_to_inspect] # TODO: add check

        files_extentions = ['m', 'h'] unless files_extentions
        extention = '{'
        files_extentions.each do |extent|
          extention += "#{extent},"
        end
        extention += '}'
        UI.message "[!] CPD analyzer will be run for all files with extentions #{files_extentions}".blue

        # prepare script and metadata for saving results
        result_dir_path = "#{work_dir}#{params[:result_dir]}"
        FileUtils.mkdir_p(result_dir_path) unless File.exist?(result_dir_path)
        result_file = "#{result_dir_path}/codeAnalysResults_clang.xml"
        run_script_path = File.join CodeStaticAnalyzer::ROOT, "assets/run_script.sh"

        UI.message 'Checking clang configuration file'
        is_clang_config = Dir.glob("#{work_dir}**/.clang-format").empty?

        if (style == 'custom' and is_clang_config) or style != 'custom'
          if is_clang_config
            UI.message 'Your custom clang configuration file (.clang-format) is absent in work directory.'.blue +
                       ' Clang will be run with default config file based on LLVM style'.blue
          end
          run_script = "clang-format -style=#{style} -dump-config "
          run_script = "#{run_script_path} \"#{run_script}\" '.clang-format'"
          FastlaneCore::CommandExecutor.execute(command: run_script.to_s,
                                                     print_all: true,
                                                     error: proc do |error_output|
                                                              # handle error here
                                                            end)
        end

        UI.message 'Check files:'
        status_static_arr = []
        work_files = file_list_for_clang_formatting(work_dir, files_to_inspect, files_to_exclude, extention)
        data_hash = {}
        data_hash["file number"] = 'number of replacements'
        testcase = ''
        work_files.each_with_index do |file, index|
          run_script = "find #{file} | xargs clang-format -i -style=file -fallback-style=none "
          clang_xml_format = " -output-replacements-xml "
          clang_changes = FastlaneCore::CommandExecutor.execute(command: "#{run_script}#{clang_xml_format}",
                                             print_all: false,
                                              print_command: false,
                                             error: proc do |error_output|
                                                      # handle error here
                                                    end)
          # if index == 22 #23
          all_lines = file_to_lines_offset(file)
          clang_data = JunitParser.parse_clang(clang_changes, file, index, all_lines)
          data_hash[index.to_s] = clang_data[0]
          Formatter.clang_format("#{index}:#{file}", clang_data[0])
          status_static_arr.push(clang_data[0])

          if autofix
            FastlaneCore::CommandExecutor.execute(command: run_script.to_s,
                                          print_all: false,
                                          print_command: false,
                                          error: proc do |error_output|
                                                   # handle error here
                                                 end)
          end
          testcase += JunitParser.create_clang_xml(clang_data[1], autofix)
          # end
          #  JunitParser.create_junit_xml(clang_changes, "#{result_dir_path}/#{index}_clang.xml")
        end

        # prepare results
        keys = data_hash.keys
        values = data_hash.values
        properties = JunitParser.add_properties(keys, values)
        junit_xml = JunitParser.add_testsuite('clang', properties + testcase)

        JunitParser.create_junit_xml(junit_xml, result_file)
        status = if status_static_arr.any? { |x| x > 0 }
                   1
                 else
                   0
                 end
        Actions.lane_context[SharedValues::CLANG_ANALYZER_STATUS] = status
      end

      def self.file_list_for_clang_formatting(work_dir, include, exclude, ext)
        file_list = []
        if include
          include.each do |file|
            file_list += Dir.glob("#{work_dir}#{file}/**/*.#{ext}")
          end
        else
          file_list = Dir.glob("#{work_dir}**/*.#{ext}")
        end
        if exclude
          exclude.each do |file|
            file_list -= Dir.glob("#{work_dir}#{file}/**/*")
          end
        end
        file_list
      end

      def self.file_to_lines_offset(file_path_name)
        line_start = []
        line_end = []
        line_num = []
        file_stream = File.open(file_path_name)
        File.readlines(file_path_name).each_with_index do |line, index|
          line_start_pos = file_stream.pos
          # linelength = line.length - 1
          line_end_pos = file_stream.pos + line.length
          file_stream.seek(line_end_pos)
          line_start.push(line_start_pos)
          line_end.push(line_end_pos)
          line_num.push(index) # in File.read index of first line - 0, but in Xcode - 1
        end
        file_stream.close
        { start: line_start, finish: line_end, line: line_num }
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

        # Below a few examples
        [
          FastlaneCore::ConfigItem.new(key: :basic_style,
                        env_name: "FL_CLANG_ANALYZER_BASED_ON_STYLE",
                        description: "Code style.\nSupported styles: #{SUPPORTED_STYLE}",
                        optional: true,
                        type: String,
                        verify_block: proc do |value|
                          UI.user_error!("This style is not supported.  Supported languages: #{SUPPORTED_STYLE}") unless SUPPORTED_STYLE.map(&:downcase).include? value.downcase or value.empty? or !value
                        end,
                        default_value: 'custom'),
          FastlaneCore::ConfigItem.new(key: :clang_dir_to_inspect,
                        env_name: "FL_CLANG_ANALYZER_FILES_TO_INSPECT",
                        description: "List of directories (relative to work directory) to inspect on clang styling",
                        optional: true,
                        type: Array),
          FastlaneCore::ConfigItem.new(key: :clang_dir_to_exclude,
                        env_name: "FL_CLANG_ANALYZER_FILES_NOT_TO_INSPECT",
                        description: "List of directories (relative to work directory) not to inspect on clang styling",
                        optional: true,
                        type: Array),
          FastlaneCore::ConfigItem.new(key: :files_extention,
                        env_name: "FL_CLANG_ANALYZER_FILES_EXTENTIONS",
                        description: "List of extentions of inspected files",
                        optional: true,
                        type: Array),
          FastlaneCore::ConfigItem.new(key: :result_dir,
                        env_name: "FL_CLANG_ANALYZER_RESULT_DIR",
                        description: "Directory's name for storing results",
                        optional: true,
                        type: String,
                        default_value: 'artifacts'),
          FastlaneCore::ConfigItem.new(key: :autocorrect,
                        env_name: "FL_CLANG_ANALYZER_AUTOCORRECT",
                        optional: true,
                        is_string: false)
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        [
          ['CLANG_ANALYZER_STATUS', 'Clang format analyzer result status (0 - success, any other value - failed)']
        ]
      end

      def self.return_value
        # If you method provides a return value, you can describe here what it does
      end

      def self.authors
        # So no one will ever forget your contribution to fastlane :) You are awesome btw!
        ["olgakn"]
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
