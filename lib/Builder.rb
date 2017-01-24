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
                  advanced_cat: raw_reader.advanced_cat,
                  concentration_cat: raw_reader.concentration_cat,
                  strains: raw_reader.strains,
                  professions: raw_reader.professions,
                  strain_stats: raw_reader.strain_stats,
                  strain_specs: raw_reader.strain_specs,
                  profession_concentrations: raw_reader.profession_concentrations,
                  profession_concentration_hierarchy: raw_reader.profession_concentration_hierarchy,
                  profession_advanced: raw_reader.profession_advanced,
                  skill_counters: raw_reader.skill_counters,
                  skill_countered: raw_reader.skill_countered

    File.open(File.join(base_output_path, 'strains.json'), 'w') { |f| f.write raw_reader.strains.to_a.to_json }
    File.open(File.join(base_output_path, 'professions.json'), 'w') { |f| f.write raw_reader.professions.to_a.to_json }
    File.open(File.join(base_output_path, 'strain_restriction.json'), 'w') { |f| f.write raw_reader.strain_restrictions.to_json }
    File.open(File.join(base_output_path, 'skill_cat.json'), 'w') { |f| f.write raw_reader.skill_cat.to_json }
    File.open(File.join(base_output_path, 'advanced_cat.json'), 'w') { |f| f.write raw_reader.advanced_cat.to_json }
    File.open(File.join(base_output_path, 'concentration_cat.json'), 'w') { |f| f.write raw_reader.concentration_cat.to_json }
    File.open(File.join(base_output_path, 'skill_group.json'), 'w') { |f| f.write raw_reader.skill_group.to_json }
    File.open(File.join(base_output_path, 'skill_list.json'), 'w') { |f| f.write raw_reader.skill_list.to_json }
    File.open(File.join(base_output_path, 'strain_stats.json'), 'w') { |f| f.write raw_reader.strain_stats.to_json }
    File.open(File.join(base_output_path, 'strain_specs.json'), 'w') { |f| f.write raw_reader.strain_specs.to_json }
    File.open(File.join(base_output_path, 'profession_concentrations.json'), 'w') { |f| f.write raw_reader.profession_concentrations.to_json }
    File.open(File.join(base_output_path, 'profession_concentration_hierarchy.json'), 'w') { |f| f.write raw_reader.profession_concentration_hierarchy.to_json }
    File.open(File.join(base_output_path, 'profession_advanced.json'), 'w') { |f| f.write raw_reader.profession_advanced.to_json }
    File.open(File.join(base_output_path, 'skill_counters.json'), 'w') { |f| f.write raw_reader.skill_counters.to_json }
    File.open(File.join(base_output_path, 'skill_countered.json'), 'w') { |f| f.write raw_reader.skill_countered.to_json }
  end
end