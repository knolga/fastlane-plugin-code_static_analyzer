require 'xcodeproj'
module Fastlane
  module Actions
    module SharedValues
      WARNING_ANALYZER_STATUS = :WARNING_ANALYZER_STATUS
    end

    class WarningAnalyzerAction < Action
      def self.run(params)
        UI.header ('iOS warning analyzer') if Actions::CodeStaticAnalyzerAction.run_from_main_action
        work_dir = Actions::CodeStaticAnalyzerAction.get_work_dir 
         
        # checking files for analysing 
        workspace = params[:xcode_workspace_name]
        project = params[:xcode_project_name]
        checked_params = Actions::CodeStaticAnalyzerAction.xcode_check_parameters(work_dir, project, workspace)
        project = checked_params[0]
        workspace = checked_params[1]
        is_workspace = false
        is_workspace = true if workspace and !workspace.empty?

        # prepare script and metadata for saving results  
        result_dir_path = "#{work_dir}#{params[:result_dir]}"
        FileUtils.mkdir_p(result_dir_path) unless File.exist?(result_dir_path)
        #lib_path = File.join(Helper.gem_path('fastlane-plugin-code_static_analyzer'), "lib")
        #File.join(lib_path, "assets/code_analys.sh")
        run_script_path = File.join CodeStaticAnalyzer::ROOT, "assets/code_analys.sh" 

        status_static_arr = []
        xml_content = ''
        temp_result_file = "#{result_dir_path}/temp_warnings.log" 
        result_file = "#{result_dir_path}/codeAnalysResults_warning.xml"

        # use analyzer and collect results 
        project_workspace = project
        project_workspace = workspace if is_workspace
        Actions::CodeStaticAnalyzerAction.start_xml_content unless Actions::CodeStaticAnalyzerAction.run_from_main_action       
        project_info = Xcodeproj::Project.open(project.to_s)
        project_info.targets.each do |target|
          Formatter.xcode_format(target.name)
          run_script = "bundle exec #{run_script_path} #{project_workspace} #{target.name} '#{temp_result_file}' #{is_workspace}" 
          FastlaneCore::CommandExecutor.execute(command: run_script.to_s,
                                        print_all: false,
                                        print_command: false,
                                        error: proc do |error_output|
                                          # handle error here
                                        end)

          Actions::CodeStaticAnalyzerAction.start_xml_content unless Actions::CodeStaticAnalyzerAction.run_from_main_action   
          if Dir.glob(temp_result_file).empty? 
            Actions::CodeStaticAnalyzerAction.add_xml_content("#{result_dir_path}/", 'iOS Warning', temp_result_file)
            Actions::CodeStaticAnalyzerAction.create_analyzers_run_result("#{result_dir_path}/") unless Actions::CodeStaticAnalyzerAction.run_from_main_action
            status_static_arr.push(1)
          else
            file = File.read(temp_result_file)
            UI.important "wrong profiles. Code isn't checked" if file =~ /BCEROR/
            is_warnings = file =~ /warning:|error:|BCEROR/
            if is_warnings
              status_static_arr.push(1)
            else
              status_static_arr.push(0)
            end
            xml_content += JunitParser.parse_xcode_log(temp_result_file, target.name, is_warnings)
          end
        end
        
        # prepare results
        if !Dir.glob(temp_result_file).empty?  
          junit_xml = JunitParser.add_testsuite('xcode warnings', xml_content)
          JunitParser.create_junit_xml(junit_xml, result_file)
        end
        status = if status_static_arr.any? { |x| x > 0 }
                   1
                 else
                   0
                 end

        Actions.lane_context[SharedValues::WARNING_ANALYZER_STATUS] = status
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "This analyzer detect warnings in Xcode projects."
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
                           env_name: "FL_WARNING_ANALYZER_RESULT_DIR",
                           description: "[optional] Directory's name for storing  analysis results",
                           optional: true,
                           type: String,
                           default_value: 'artifacts'),
          FastlaneCore::ConfigItem.new(key: :xcode_project_name,
                           env_name: "FL_WARNING_ANALYZER_PROJECT_NAME",
                           description: "Xcode project name in work directory",
                           optional: false,
                           type: String,
                           verify_block: proc do |value|
                             UI.user_error!("No project name for WarningAnalyzerAction given, pass using `project_name` parameter") unless value and !value.empty?
                           end),
          FastlaneCore::ConfigItem.new(key: :xcode_workspace_name,
                           env_name: "FL_WARNING_ANALYZER_WORKSPACE_NAME",
                           description: "[optional] Xcode workspace name in work directory. Set it if you use different project & workspace names",
                           optional: true,
                           type: String)
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        [
          ['WARNING_ANALYZER_STATUS', 'Warning analyzer result status (0 - success, any other value - failed)']
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
		[:ios, :mac].include?(platform)
      end
    end
  end
end
