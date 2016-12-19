module Fastlane
  module Actions
    module SharedValues
      ANALYZER_STATUS = :ANALYZER_STATUS
    end
    
    class CodeStaticAnalyzerAction < Action
      SRCROOT = './artifacts/'
      
      def self.run(params)
       # UI.message("The code_static_analyzer plugin is working!")
        #"The code_static_analyzer plugin is working! Coloured" #.light_blue
       # Fastlane::Actions::JunitParserAction#(text: "Please input your password:")
       # Actions::JunitParserAction.run(api_token: 'ASD-23-F', development: true)
        
       # Actions::FormatterAction.run(api_token: 'myTest-script')
       #  UI.message("end!")
       
       ##===================================================##
       
       	junit_xml = ''
		
		clear_files = "#{SRCROOT}*.*"
		sh "rm -rf #{clear_files}"
		xml_content = Actions::CodeStaticAnalyzerAction.CPD_analyzer
		
		# add block of one static analys results
        #junit_xml += xml_content #Parser.add_testsuite('1', 'copypaste', xml_content)
        
        if Actions::CodeStaticAnalyzerAction.status_to_boolean(xml_content) #&& status_static
   			#status_to_boolean(status_cpd) &&
   #status_to_boolean(status_rubocop)
  			UI.success 'Success. New builds can be prepared.'
  			 Actions.lane_context[SharedValues::ANALYZER_STATUS] = 0
            #exit 0
		else
  			UI.error 'Failed. New builds deprecated. Warnings (see more in *.xml files)'
  			 Actions.lane_context[SharedValues::ANALYZER_STATUS] = 1
  			#exit 1
		end
 #Actions.lane_context[SharedValues::ANALYZER_STATUS] = 0
      end
      
      def self.CPD_analyzer
        xml_content = ''
      UI.header('Run copy-paste detector')
        run_script = 'bundle exec ./cpd_code_analys.sh'
     run_script =   "pmd cpd "\
	"--minimum-tokens 100 "\
 	"--files . "\
 	"--language objectivec "\
 	"--exclude ./Pods ./ThirdParty/ "\
 	"--format xml > '#{SRCROOT}copypaste.xml'"
        Actions::FormatterAction.cpd_format('100','objective c','./Pods ./ThirdParty/',"#{SRCROOT}copypaste.xml")

        FastlaneCore::CommandExecutor.execute(command: "#{run_script}",
                                    print_all: false,
                                        error: proc do |error_output|
                                          # handle error here
                                        end)
        status_cpd = $?.exitstatus
       
       # xml_content =
       # Parser.parse_xml_to_xml('copypaste.xml', 'copypaste')
       # Formatter.return_status(status_cpd)
         status_cpd
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
        [
          # FastlaneCore::ConfigItem.new(key: :root,
          #                         env_name: "SRCROOT",
          #                      description: "A description of your option",
          #                         optional: false,
          #                             type: String)
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
