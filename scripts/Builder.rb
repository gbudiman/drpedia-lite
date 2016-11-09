require 'ap'
require 'trollop'
require_relative 'RawReader.rb'
require_relative 'Validator.rb'

opts = Trollop::options do
end

raw_reader = RawReader.new filepath: ARGV[0]
Validator.new skill_list: raw_reader.skill_list, 
              skill_cat: raw_reader.skill_cat