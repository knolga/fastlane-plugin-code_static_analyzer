require 'xcodeproj' 
module Fastlane
  module Actions
    module SharedValues
      WARNING_ANALYZER_STATUS = :WARNING_ANALYZER_STATUS
    end

    class WarningAnalyzerAction < Action
      def self.run(params)
        raise "Wrong path '#{params[:work_dir]}/#{params[:project_name]}' or you have different names for project & workspace" unless (File.exist?("#{params[:work_dir]}/#{params[:project_name]}.xcodeproj") or File.exist?("#{params[:work_dir]}/#{params[:project_name]}.xcworkspace"))                                  
        FileUtils.mkdir_p("#{params[:work_dir]}/#{params[:result_dir]}") unless File.exist?("#{params[:work_dir]}/#{params[:result_dir]}")
        lib_path = File.join(Helper.gem_path('fastlane-plugin-code_static_analyzer'), "lib")
        run_script_path = File.join(lib_path, "assets/code_analys.sh")
  
		status_static_arr = []
		xml_content=''
        temp_result_file = "#{params[:work_dir]}/#{params[:result_dir]}/temp_warnings.log" #log_file
        result_file = "#{params[:work_dir]}/#{params[:result_dir]}/codeAnalysResults_warning.xml"
    
        project = Xcodeproj::Project.open("#{params[:project_name]}.xcodeproj")
		project.targets.each do |target| 
  		  Actions::FormatterAction.xcode_format(target.name)
		  run_script = "#{run_script_path} #{params[:project_name]}.xcworkspace #{target.name} #{temp_result_file} "

    	  FastlaneCore::CommandExecutor.execute(command: "#{run_script}",
                            			     print_all: false,
                            			     print_command: false,
                                			 error: proc do |error_output|
                                  				# handle error here
                                			 end)
    	  file = File.read(temp_result_file)
    	  UI.important "wrong profiles. Code isn't checked" if file =~ /BCEROR/
  		  is_warnings = file =~ /warning:|error:|BCEROR/
  		  if is_warnings
    		status_static_arr.push(1)
  		  else
    		status_static_arr.push(0)
  		  end
  		  xml_content += Actions::JunitParserAction.parse_xcode_log(temp_result_file, target.name, is_warnings) 
		end
		junit_xml = Actions::JunitParserAction.add_testsuite('xcode warnings', xml_content)
        # create full file with results
		Actions::JunitParserAction.create_junit_xml(junit_xml, result_file)
		
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
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports. 
        [
          FastlaneCore::ConfigItem.new(key: :work_dir,  
           								env_name: "FL_WARNING_ANALYZER_WORK_DIR",
                     				  	description: "Path to work/project directory",
                        			  	optional: false,
                            		  	type: String,
                            		  	verify_block: proc do |value|
                                          UI.user_error!("No work directory for WarningAnalyzerAction given, pass using `work_dir` parameter") unless (value and not value.empty?)
                                          UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
                                      	end),    
          FastlaneCore::ConfigItem.new(key: :result_dir,   
           								env_name: "FL_WARNING_ANALYZER_RESULT_DIR",
                     					description: "Directory's name for storing  analysis results",
                        				optional: true,
                            			type: String,
                            			default_value: 'artifacts'),
          FastlaneCore::ConfigItem.new(key: :project_name,
                                       env_name: "FL_WARNING_ANALYZER_PROJECT_NAME",
                                       description: "Xcode project-workspace name (without extention) in work directory", 
                                       optional: false,
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

        platform == :ios
      end
    end
  end
end
