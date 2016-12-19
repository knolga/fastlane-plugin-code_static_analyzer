module Fastlane
  module Actions
    module SharedValues
      JUNIT_DATA = :JUNIT_DATA
    end

    class JunitParserAction < Action
    
    require 'crack'
      
      def self.run(params)
      puts params
        # fastlane will take care of reading in the parameter and fetching the environment variable:
        #UI.message "Required Parameter API Token: #{params[:api_token]}"
 		#UI.message "Optional Parameter develop  : #{params[:development]}"
        # sh "shellcommand ./path"
    

        # Actions.lane_context[SharedValues::JUNIT_PARSER_CUSTOM_VALUE] = "my_val"
      end

      #####################################################
      # ================= For all parsers =================
      #####################################################

      def self.create_xml(root_data, full_data, end_tag, result_file_name)
        xml_data = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml_data += root_data
        xml_data += full_data
        xml_data += end_tag
        File.open(file_path("#{result_file_name}.xml"), 'w') do |f|
          f.write(xml_data)
        end
      end
  
      def self.create_xml2(xml_data_custom, result_file_name)
        xml_data = '<?xml version="1.0" encoding="UTF-8"?>'
        xml_data += xml_data_custom
        File.open("#{result_file_name}.xml", 'w') do |f|
          f.write(xml_data)
        end
      end
    
      def self.create_testsuites(testsuites)
        "#{xml_level(0)}<testsuites>#{testsuites}#{xml_level(0)}</testsuites>"
      end
    
      def self.add_testsuite(id, name, testcases)
        "#{xml_level(1)}<testsuite id='#{id}' name='#{name}'>" \
        "#{testcases}" \
        "#{xml_level(1)}</testsuite>"
      end
    
      def self.add_failed_testcase(id, name, failures)
        "#{xml_level(2)}<testcase #{insert_attribute('id', id)} name='#{name}'>" \
        "#{failures}#{xml_level(2)}</testcase>"
      end
    
      def self.add_success_testcase(_id, name)
        "#{xml_level(2)}<testcase  name='#{name}' status='success'/>"
      end
    
      def self.add_failure(message, type, text)
        "#{xml_level(3)}<failure #{insert_attribute('type', type)} status='failed' " \
        "#{insert_attribute('message', message)}>" \
      	"#{text}" \
      	"#{xml_level(3)}</failure>"
      end
    
      def self.add_properties(property_array, value_array)
        properties = "#{xml_level(2)}<properties>"
        property_array.each_with_index do |property, index|
          value = value_array[index]
          unless value.nil?
            properties += "#{xml_level(3)}<property name='#{property}' value='#{value}' />"
          end
        end
        properties += "#{xml_level(2)}</properties>"
      end
    
      def self.construct_failure_mes(attributes, values)
        properties = xml_level(0).to_s
        attributes.each_with_index do |property, index|
          value = values[index]
          properties += format("#{xml_level(4)}%-18s: %s", property, value) unless value.nil?
        end
        properties
      end
    
      def self.insert_attribute(attribute, value)
        value == '' ? '' : "#{attribute}='#{value}'"
      end
    
      def self.get_failure_type(str)
        failure_type = str[/\[(.*?)\]/, 1]
        failure_type = '-W' if failure_type.nil?
        failure_type
      end
    
      def self.xml_level(level)
        levelstr = "\n"
        i = 1
        while i < level
          levelstr += "\s\s"
          i += 1
        end
        levelstr
      end
      
      # create root xml content
      def self.create_code_analysis_junit_xml(testsuite, result_file_name)
        full_data = create_testsuites(testsuite)
        create_xml2(full_data, result_file_name)
      end
  
      #####################################################
      # ==================== Parser 3 =====================
      #####################################################

      def self.parse_xml_to_xml(file)
        data_read = File.read(file)
        data_hash = Crack::XML.parse(data_read)
    
        if data_hash.empty?
          puts 'empty data_hash'
          Actions::JunitParserAction.add_success_testcase('', 'casino duplications')
        else
          Actions::JunitParserAction.parse_code_duplications(data_hash)
        end
      end
    
      def self.parse_code_duplications(data_hash)
        xml = ''
        duplications = data_hash['pmd_cpd']['duplication']
        if duplications.is_a?(Array)
          index = 1
          duplications.each do |error|
            parsed_files = Actions::JunitParserAction.parse_inspected_files2(error['file'])
            failure = Actions::JunitParserAction.add_failure("lines:#{error['lines']} tokens:#{error['tokens']} #{xml_level(3)}files:#{parsed_files}", '', "\n#{error['codefragment']}")
            xml += Actions::JunitParserAction.add_failed_testcase('', "duplication #{index}", failure)
            index += 1
          end
        else
          parsed_files = Actions::JunitParserAction.parse_inspected_files2(duplications['file'])
          failure = Actions::JunitParserAction.add_failure("lines:#{duplications['lines']} tokens:#{duplications['tokens']} #{xml_level(3)}files:#{parsed_files}", '',
                                "\n #{duplications['codefragment']}")
          xml += Actions::JunitParserAction.add_failed_testcase('', 'single duplication', failure)
        end
        xml
      end
    
    def self.parse_inspected_files2(file_list)
        index = 1
        file_list_info = []
        file_list.each do |file|
          file_list_info.push("File #{index}: #{file['path']}::#{file['line']}")
          index += 1
        end
        file_list_info
      end
      
      def self.parse_inspected_files(file_list)
        index = 1
        information = []
        headers = []
        file_list.each do |file|
          information.push("#{file['path']}::#{file['line']}")
          headers.push("File #{index}")
          index += 1
        end
        [headers, information]
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
       #   FastlaneCore::ConfigItem.new(key: :parser_action,
       #                                env_name: "FL_JUNIT_PARSER_ACTION", # The name of the environment variable
       #                                description: "To decetect which function to call parse/create..", # a short description of this parameter
       #                                verify_block: proc do |value|
       #                                   UI.user_error!("No parser_action for JunitParserAction given, pass using `parser_action: 'xml/json/log/new_testsuite/full_result'`") unless (value and not value.empty?)
       #                                   # UI.user_error!("Couldn't find file at path '#{value}'") unless File.exist?(value)
       #                                end),
       #   FastlaneCore::ConfigItem.new(key: :file_to_parse,
       #                                env_name: "FL_JUNIT_PARSER_FILE_PARSED",
       #                                description: "Path/to/file.with_extention for parsing",
       #                                verify_block: proc do |value|
       #                                   UI.user_error!("Couldn't find file at path '#{value}'") unless (File.exist?(value) or value.empty?)
       #                                end)
       #                                #is_string: false, # true: verifies the input is a string, false: every kind of value
                                       #default_value: false) # the default value if the user didn't provide one
        ]
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          ['JUNIT_DATA', 'Return input data in junit xml format']
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
