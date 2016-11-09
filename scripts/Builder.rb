require 'ap'
require 'trollop'
require 'json'
require_relative 'RawReader.rb'
require_relative 'Validator.rb'

opts = Trollop::options do
end

raw_reader = RawReader.new filepath: ARGV[0]
Validator.new skill_list: raw_reader.skill_list, 
              skill_cat: raw_reader.skill_cat,
              strains: raw_reader.strains,
              professions: raw_reader.professions

base_output_path = ARGV[1]
File.open(File.join(base_output_path, 'strains.json'), 'w') { |f| f.write raw_reader.strains.to_a.to_json }
File.open(File.join(base_output_path, 'professions.json'), 'w') { |f| f.write raw_reader.professions.to_a.to_json }
File.open(File.join(base_output_path, 'skill_cat.json'), 'w') { |f| f.write raw_reader.skill_cat.to_json }
File.open(File.join(base_output_path, 'skill_list.json'), 'w') { |f| f.write raw_reader.skill_list.keys.to_json }