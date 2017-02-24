#! /usr/bin/env ruby
# parser.sh
# @desc Parser
# @usage
# 1. Parser 1. Xcode analyze result (.log)
# 2. Parser 2. Rubocop result (.json)
# 3. Parser 3. CPD result (.xml)
# 4. Parser 4. Any result as required Hash (ruby hash)

require 'crack'

module JunitParser
  SKIP_STR_IN_MATCH = ['*', '\n', '\\', '//']

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

  def self.add_success_testcase(name, assertions)
    "#{xml_level(2)}<testcase name='#{name}' #{insert_attribute('assertions', assertions)} status='success'/>"
  end

  def self.add_skipped_testcase(name, assertions, message)
    out = message == '' ? '' : add_system_output(message)
    "#{xml_level(2)}<testcase #{insert_attribute('name', name)} #{insert_attribute('assertions', assertions)}>" \
    "#{out}#{xml_level(3)}<skipped/>#{xml_level(2)}</testcase>"
  end

  def self.add_failure(message, type, text)
    "#{xml_level(3)}<failure #{insert_attribute('type', type)} status='failed' " \
    "#{insert_attribute('message', message)}>" \
  	"#{text}" \
  	"#{xml_level(3)}</failure>"
  end

  def self.add_system_output(text)
    "#{xml_level(3)}<system-out>#{text}#{xml_level(3)}</system-out>"
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
    properties = ''
    attributes.each_with_index do |property, index|
      value = values[index]
      properties += format("#{xml_level(4)}%-18s: %s", property, value) unless value.nil?
    end
    properties
  end

  def self.insert_attribute(attribute, value)
    (value == '' or value.nil?) ? '' : "#{attribute}='#{value}'"
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
        next unless line =~ /warning:|error:|BCEROR/
        failure_type = get_failure_type(line)
        warning_params = line.split(':')
        if warning_params.count == 5
          error_text = construct_failure_mes(
            ['Error ClassType', 'Error Message'],
            [failure_type, warning_params[4].tr("\n", '')]
          )
          testcase_name = project + ':' + warning_params[0].tr('<', '').tr('>', '') +
                          ":#{warning_params[1]}:#{warning_params[2]}"
        else
          error_text = construct_failure_mes(
            ['Error ClassType', 'Error Message'],
            [failure_type, line.tr("\n", '').gsub('warning:', '')]
          )
          testcase_name = project
          testcase_name += ':project configuration' if line =~ /BCEROR/
          file_info = check_for_file_info(warning_params)
          testcase_name += ":#{file_info[0]}" unless file_info[0].nil?
          testcase_name += ":#{file_info[1]}" unless file_info[1].nil?
        end
        failures = add_failure('', '', error_text)
        temp_testcase += add_failed_testcase(testcase_name, failures)
      end
      temp_testcase
    else
      add_success_testcase(project, '')
    end
  end

  def self.check_for_file_info(text_list)
    result = []
    text_list.each_with_index do |text, i|
      file = %r{([a-zA-Z0-9\.]*)?(/[a-zA-Z0-9\._-]+)*(\.){1}[a-zA-Z0-9\._-]+}.match(text)
      file = nil if file.to_s =~ /\.{2,}/
      next if file.nil?
      next_value = text_list.to_a[i.to_i + 1].nil? ? '' : text_list.to_a[i.to_i + 1]
      line = /[0-9]+/.match(next_value)
      if line.nil?
        result = [file]
      else
        result = [file, line]
      end
      break
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
        xml += add_success_testcase((inspected_file['path']).to_s, '')
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

    if data_hash.empty? or data_hash['pmd_cpd'].nil?
      puts 'empty data_hash'
      add_success_testcase('casino duplications', '')
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

  #####################################################
  # =================== Clang Parser ==================
  #####################################################

  def self.parse_clang(clang_changes, inspected_file, file_id, file_lines)
    count = 0
    file_replacements = []
    clang_changes.each_line do |line|
      next unless line =~ %r{</replacement>}
      hash = parse_str(line)
      offset = hash[:offset]
      offset_long = hash[:length]
      offset_end = offset.to_i + offset_long.to_i
      code_lines = get_code_lines(offset, offset_end, file_lines)
      # read current code fragment that include clang format issue
      current_code_fragment = read_lines_in_file(inspected_file, code_lines[0], code_lines[1], false)

      # make clang format replacement more understandable
      replacements = hash[:replacements]
      fixed_code_fragment = replacements
      fixed_code_fragment = replacements.sub("&#10;", '') if replacements =~ /(&#10;){2,}./
      fixed_code_fragment.gsub!("&#10;", "\n")
      replace_in(fixed_code_fragment)
      fixed_code_fragment = "\n'#{add_code(fixed_code_fragment)}'"

      # if replacements.match(/^([a-zA-Z0-9])[\n&#10;]*(\ )*$/)
      #   if offset_long.to_i == 1
      #     fixed_code_fragment = "change one character (remove/add space/tab/new line). Replacement: #{fixed_code_fragment.sub("\n", '')}"
      #   else
      #     fixed_code_fragment = "generally needed to remove/add space/tab/new line. Replacement: #{fixed_code_fragment.sub("\n", '')}"
      #   end
      # end

      hash_info = { old_code: current_code_fragment,
      fix_code: fixed_code_fragment,
      code_lines: code_lines,
      file: inspected_file,
      file_id: file_id }
      file_replacements.push(hash_info)

      count += 1
    end
    [count, file_replacements]
  end

  def self.create_clang_xml(file_replacements, skipped)
    xml = ''
    file_replacements.each do |i_hash|
      if skipped
        new_code_fragment = read_lines_in_file(i_hash[:file], i_hash[:code_lines][0], i_hash[:code_lines][1], true)
        error_text = construct_failure_mes(
          ['Code fragment with formatting issue', "#{xml_level(4)}Clang fix", "#{xml_level(4)}Code fragment after clang fix"],
          [i_hash[:old_code], i_hash[:fix_code], new_code_fragment]
        )
        xml += add_skipped_testcase("F#{i_hash[:file_id]}:#{i_hash[:file]}:#{i_hash[:code_lines][0] + 1}", '', error_text)
      else
        error_text = construct_failure_mes(
          ['Code fragment with formatting issue', "#{xml_level(4)}Clang fix"],
          [i_hash[:old_code], i_hash[:fix_code]]
        )
        failure = add_failure('', '', error_text)
        xml += add_failed_testcase("F#{i_hash[:file_id]}:#{i_hash[:file]}:#{i_hash[:code_lines][0] + 1}", failure)
      end
    end
    xml
  end

  def self.read_lines_in_file(file, read_start, read_to, is_fixed)
    lines = ''
    read_from = (read_start - 5) < 0 ? 0 : (read_start - 5)
    read_to += 5
    index = read_from
    space_count = read_to.to_s.count "0-9"
    File.readlines(file).values_at(read_from..read_to).each do |spec_line|
      unless spec_line.nil?
        spec_line = spec_line.chomp
        replace_in(spec_line)
        if index == read_start and !is_fixed
          lines += format("\n&#62;&#62;&#32;%-#{space_count}s&#32;%s", (index + 1), add_code(spec_line))
        else
          lines += format("\n&#32;&#32;&#32;%-#{space_count}s&#32;%s", (index + 1), add_code(spec_line))
        end
      end
      index += 1
    end
    lines
  end

  def self.parse_str(str)
    # TODO: check if no any replacements...will it be crashes
    byte_offset = str.match(/offset='[0-9]+'/).to_s.tr('\'', '').split('=')[1]
    length_of_changes = str.match(/length='[0-9]+'/).to_s.tr('\'', '').split('=')[1]
    replaced = str.match(%r{>(.)*</replacement>}).to_s
    replaced[0] = ''
    replaced = replaced.sub('</replacement>', '')

    { offset: byte_offset, length: length_of_changes, replacements: replaced }
  end

  def self.get_code_lines(value, value_end, file_lines)
    s_line = file_lines[:start]
    e_line = file_lines[:finish]
    value = value.to_i
    start_flag = false
    finish_flag = false
    start = 0
    finish = 0
    s_line.each_with_index do |line, index|
      if value >= line and value < e_line[index] and !start_flag
        start = file_lines[:line][index]
        start_flag = true
      end
      if value_end > line and value_end <= e_line[index] and !finish_flag
        finish = file_lines[:line][index]
        finish_flag = true
      end
      break if start_flag and finish_flag
    end
    [start, finish]
  end

  def self.replace_in(text)
    text.gsub!("&lt;",'<')
    text.gsub!("&gt;",'>')
    text.gsub!("&quot;",'"')
    text.gsub!("&amp;",'&')
    text.gsub!("&apos;",'\'')
  end

  #####################################################
  # ============== Universal Hash Parser ==============
  #####################################################

  # Method return testsuites xml content
  # after that call create_junit_xml to get full JUnit file
  def self.parse_hash(data_hash)
    testcase_xml = ''
    testcases = data_hash[:testcase]
    testcases.each do |error|
      testcase_name = error[:name]
      testcase_err_num = error[:assertions]
      testcase_message = error[:message]
      case error[:status].downcase
      when 'success'
        testcase_xml += add_success_testcase(testcase_name, testcase_err_num, '')
      when 'fail'
        if testcase_message.nil?
          failure = add_failure('', '', '')
        else
          failure = add_failure(testcase_message[:additional_info], testcase_message[:type], testcase_message[:message])
        end
        testcase_xml += add_failed_testcase(testcase_name, failure)
      when 'skip'
        testcase_xml += add_skipped_testcase(testcase_name, testcase_err_num, '')
      end
    end
    properties = ''
    unless data_hash[:properties].nil?
      keys = data_hash[:properties].keys
      values = data_hash[:properties].values
      properties = add_properties(keys, values)
    end
    testsuite = add_testsuite(data_hash[:test_group_name], properties + testcase_xml)
    testsuite
  end
end
