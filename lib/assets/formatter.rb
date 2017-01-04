#! /usr/bin/env ruby
# output_looking.rb
# @desc Tools for preparing better looking running output
# @usage
# in needed file paste string: require './path-to-file/output_looking.rb

# Use to prepare formatted output
module Formatter
  def self.return_status(mystatus)
    puts light_blue(">>> Exit command status: #{mystatus}")
  end

  def self.xcode_format(scheme)
    puts ">>> Running Xcode analyze command... on #{scheme}..."
  end

  def self.cpd_format(tokens, language, exclude, result_file, inspect)
    puts "files         : #{inspect}"
    puts "min_tokens    : #{tokens}"
    puts "language      : #{language}"
    puts "exclude_files : #{exclude}"
    puts 'format        : xml'
    puts "output_file   : #{result_file}"
  end

  # String colorization
  # call UI.message Actions::FormatterAction.light_blue(text)
  def self.light_blue(mytext)
    "\e[36m#{mytext}\e[0m"
  end
end
