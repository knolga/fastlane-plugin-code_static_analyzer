require 'crack'
module Fastlane
  module Actions
    # module SharedValues
    #   JUNIT_DATA = :JUNIT_DATA
    # end

    class JunitParserAction < Action
      def self.run(params)
        # fastlane will take care of reading in the parameter and fetching the environment variable:
        # UI.message "Required Parameter API Token: #{params[:api_token]}"
        # Actions.lane_context[SharedValues::JUNIT_PARSER_CUSTOM_VALUE] = "my_val"
      end

      #####################################################
      # ================= For all parsers =================
      #####################################################

      def self.create_xml(xml_data_custom, result_file_name)
        xml_data = '<?xml version="1.0" encoding="UTF-8"?>'
        xml_data += xml_data_custom
        File.open(result_file_name, 'w') do |f|
          f.write(xml_data)
        end
      end

      def self.create_testsuites(testsuites)
        "#{xml_level(0)}<testsuites>#{testsuites}#{xml_level(0)}</testsuites>"
      end

      def self.add_testsuite(name, testcases)
        "#{xml_level(1)}<testsuite name='#{name}'>" \
        "#{testcases}" \
        "#{xml_level(1)}</testsuite>"
      end

      def self.add_failed_testcase(name, failures)
        "#{xml_level(2)}<testcase name='#{name}'>" \
        "#{failures}#{xml_level(2)}</testcase>"
      end

      def self.add_success_testcase(name)
        "#{xml_level(2)}<testcase name='#{name}' status='success'/>"
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
      def self.create_junit_xml(testsuite, result_file_name)
        full_data = create_testsuites(testsuite)
        create_xml(full_data, result_file_name)
      end

      #####################################################
      # ============== Xcode-log Parser ================
      #####################################################

      def self.parse_xcode_log(file, project, is_warn)
        if is_warn
          error_text = ''
          File.open(file).each do |line|
            if line =~ /warning:|error:/
              warning_params = line.split(':')
              error_text += Actions::JunitParserAction.construct_failure_mes(
                ['Error ClassType', 'Error in File', 'Error Line', 'Error Message'],
                [Actions::JunitParserAction.get_failure_type(warning_params[4]), warning_params[0].tr('<', '').tr('>', ''),
                 "#{warning_params[1]}:#{warning_params[2]}", warning_params[4].tr("\n", '')]
              )
            end
            next unless line =~ /BCEROR/
            error_text += Actions::JunitParserAction.construct_failure_mes(['Error ClassType', 'Error in File', 'Error Message'],
                                                                           [Actions::JunitParserAction.get_failure_type(line), 'project configuration',
                                                                            line.tr("\n", '')])
          end
          failures = Actions::JunitParserAction.add_failure('', '', error_text)
          Actions::JunitParserAction.add_failed_testcase(project, failures)
        else
          Actions::JunitParserAction.add_success_testcase(project)
        end
      end

      #####################################################
      # ============== Rubocop-json Parser ================
      #####################################################

      def self.parse_json(file)
        data_read = File.read(file)
        data_hash = Crack::JSON.parse(data_read)

        keys = data_hash['metadata'].keys.zip(data_hash['summary'].keys).flatten.compact
        values = data_hash['metadata'].values.zip(data_hash['summary'].values).flatten.compact
        properties = add_properties(keys, values)

        testcase = Actions::JunitParserAction.parse_main_json(data_hash)

        properties + testcase
      end

      # create main xml content
      def self.parse_main_json(data_hash)
        xml = ''
        data_hash['files'].each do |inspected_file|
          error_text = ''
          errors = inspected_file['offenses']
          if errors.empty?
            xml += Actions::JunitParserAction.add_success_testcase((inspected_file['path']).to_s)
          else
            errors.each do |error|
              error_text += Actions::JunitParserAction.construct_failure_mes(
                ['Error isCorrected', 'Error ClassType', 'Error Line', 'Error Message'],
                [error['corrected'], "#{error['cop_name']} (#{error['severity']})",
                 Actions::JunitParserAction.parse_location(error['location']), error['message'].tr("\n", '')]
              )
            end
            # TODO: corrected:6 failded:0 (if needed this info)
            failures = Actions::JunitParserAction.add_failure('lineformat=line:column:length', '', error_text)
            xml += Actions::JunitParserAction.add_failed_testcase((inspected_file['path']).to_s, failures)
          end
        end
        xml
      end

      def self.parse_location(location)
        "#{location['line']}:#{location['column']}:#{location['length']}"
      end

      #####################################################
      # ================= CPD-xml Parser ==================
      #####################################################

      def self.parse_xml(file)
        data_read = File.read(file)
        data_hash = Crack::XML.parse(data_read)

        if data_hash.empty?
          puts 'empty data_hash'
          Actions::JunitParserAction.add_success_testcase('casino duplications')
        else
          Actions::JunitParserAction.parse_code_duplications(data_hash)
        end
      end

      def self.parse_code_duplications(data_hash)
        xml = ''
        duplications = data_hash['pmd_cpd']['duplication']
        if duplications.kind_of?(Array)
          index = 1
          duplications.each do |error|
            parsed_files = Actions::JunitParserAction.parse_inspected_files(error['file'])
            failure = Actions::JunitParserAction.add_failure("lines:#{error['lines']} tokens:#{error['tokens']} #{xml_level(3)}files:#{parsed_files}", '', "\n#{error['codefragment']}")
            xml += Actions::JunitParserAction.add_failed_testcase("duplication #{index}", failure)
            index += 1
          end
        else
          parsed_files = Actions::JunitParserAction.parse_inspected_files(duplications['file'])
          failure = Actions::JunitParserAction.add_failure("lines:#{duplications['lines']} tokens:#{duplications['tokens']} #{xml_level(3)}files:#{parsed_files}", '',
                                                           "\n #{duplications['codefragment']}")
          xml += Actions::JunitParserAction.add_failed_testcase('single duplication', failure)
        end
        xml
      end

      def self.parse_inspected_files(file_list)
        index = 1
        file_list_info = []
        file_list.each do |file|
          file_list_info.push("File #{index}: #{file['path']}::#{file['line']}")
          index += 1
        end
        file_list_info
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "parse resulting files of different static analyzers to junit format"
      end

      def self.details
        # Optional:
        # this is your chance to provide a more detailed description of this action
        "You can use this action to do cool things..."
      end

      def self.available_options
        # Define all options your action supports.
      end

      def self.output
        # Define the shared values you are going to provide
        # Example
        [
          # ['JUNIT_DATA', 'Return input data in junit xml format']
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
