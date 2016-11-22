require 'ap'
require 'json'
require_relative 'RawReader.rb'
require_relative 'Validator.rb'

class Builder
  def self.build input:, base_output_path:
    raw_reader = RawReader.new filepath: input
    Validator.new skill_list: raw_reader.skill_list, 
                  skill_group: raw_reader.skill_group,
                  skill_cat: raw_reader.skill_cat,
                  strains: raw_reader.strains,
                  professions: raw_reader.professions,
                  strain_stats: raw_reader.strain_stats,
                  strain_specs: raw_reader.strain_specs

    File.open(File.join(base_output_path, 'strains.json'), 'w') { |f| f.write raw_reader.strains.to_a.to_json }
    File.open(File.join(base_output_path, 'professions.json'), 'w') { |f| f.write raw_reader.professions.to_a.to_json }
    File.open(File.join(base_output_path, 'strain_restriction.json'), 'w') { |f| f.write raw_reader.strain_restrictions.to_json }
    File.open(File.join(base_output_path, 'skill_cat.json'), 'w') { |f| f.write raw_reader.skill_cat.to_json }
    File.open(File.join(base_output_path, 'skill_group.json'), 'w') { |f| f.write raw_reader.skill_group.to_json }
    File.open(File.join(base_output_path, 'skill_list.json'), 'w') { |f| f.write raw_reader.skill_list.to_json }
    File.open(File.join(base_output_path, 'strain_stats.json'), 'w') { |f| f.write raw_reader.strain_stats.to_json }
    File.open(File.join(base_output_path, 'strain_specs.json'), 'w') { |f| f.write raw_reader.strain_specs.to_json }
  end
end