#! /usr/bin/env ruby
# parser.sh
# @desc Parser
# @usage
# 1. Parser 1. Xcode analyze result (.log)
# 2. Parser 2. Rubocop result (.json)
# 3. Parser 3. CPD result (.xml)

require 'crack'

module JunitParser
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

  def self.add_code(codefragment)
    "<![CDATA[#{codefragment}]]>"
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
      temp_testcase = ''
      File.open(file).each do |line|
        if line =~ /warning:|error:|BCEROR/
        failure_type = get_failure_type(line)
          warning_params = line.split(':')
          if warning_params.count == 5
             error_text = construct_failure_mes(
              ['Error ClassType', 'Error Message'],
              [failure_type, warning_params[4].tr("\n", '')]
            )
            testcase_name = project+':'+warning_params[0].tr('<', '').tr('>', '')+
               ":#{warning_params[1]}:#{warning_params[2]}"
          else
            error_text = construct_failure_mes(
              ['Error ClassType', 'Error Message'],
              [failure_type, line.tr("\n", '').gsub('warning:','')]
            )
            testcase_name = project
            testcase_name += ':project configuration' if line =~ /BCEROR/
            file_info = check_for_file_info(warning_params)
            testcase_name += ":#{file_info[0]}" unless file_info[0]==nil
            testcase_name += ":#{file_info[1]}" unless file_info[1]==nil
          end
          failures = add_failure('', '', error_text)
          temp_testcase += add_failed_testcase(testcase_name, failures)
        end
      end
      temp_testcase
    else
      add_success_testcase(project)
    end
  end
  
  def self.check_for_file_info(text_list)
    result =[]
    text_list.each_with_index do |text, i|
      file = /([a-zA-Z0-9\.]*)?(\/[a-zA-Z0-9\._-]+)*(\.){1}[a-zA-Z0-9\._-]+/.match(text)
      file = nil if file.to_s =~ /\.{2,}/
      unless file==nil 
        next_value=text_list.to_a[i.to_i+1].nil? ? '' : text_list.to_a[i.to_i+1]
     	line = /[0-9]+/.match(next_value)
     	if line ==nil
     	  result=[file]
     	else
     	  result=[file, line]
     	end
     	break
      end 
    end
    result
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

    testcase = parse_main_json(data_hash)

    properties + testcase
  end

  # create main xml content
  def self.parse_main_json(data_hash)
    xml = ''
    data_hash['files'].each do |inspected_file|
      error_text = ''
      errors = inspected_file['offenses']
      if errors.empty?
        xml += add_success_testcase((inspected_file['path']).to_s)
      else
        errors.each do |error|
          error_text += construct_failure_mes(
            ['Error isCorrected', 'Error ClassType', 'Error Line', 'Error Message'],
            [error['corrected'], "#{error['cop_name']} (#{error['severity']})",
             parse_location(error['location']), error['message'].tr("\n", '')]
          )
        end
        # TODO: corrected:6 failded:0 (if needed this info)
        failures = add_failure('lineformat=line:column:length', '', error_text)
        xml += add_failed_testcase((inspected_file['path']).to_s, failures)
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

    if data_hash.empty? or data_hash['pmd_cpd']==nil
      puts 'empty data_hash'
      add_success_testcase('casino duplications')
    else
      parse_code_duplications(data_hash)
    end
  end

  def self.parse_code_duplications(data_hash)
    xml = ''
    duplications = data_hash['pmd_cpd']['duplication']
    if duplications.kind_of?(Array)
      index = 1
      duplications.each do |error|
        parsed_files = parse_inspected_files(error['file'])
        failure = add_failure("lines:#{error['lines']} tokens:#{error['tokens']} #{xml_level(3)}files:#{parsed_files}", '', "\n#{add_code(error['codefragment'])}")
        xml += add_failed_testcase("duplication #{index}", failure)
        index += 1
      end
    else
      parsed_files = parse_inspected_files(duplications['file'])
      failure = add_failure("lines:#{duplications['lines']} tokens:#{duplications['tokens']} #{xml_level(3)}files:#{parsed_files}", '',
                            "\n #{add_code(duplications['codefragment'])}")
      xml += add_failed_testcase('single duplication', failure)
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
end
