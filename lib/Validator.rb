require 'test/unit/assertions'

class Validator
  include Test::Unit::Assertions
  def initialize skill_list:, 
                 skill_group:, 
                 skill_cat:, 
                 strains:, 
                 professions:, 
                 strain_stats:, 
                 strain_specs:
    @skill_list = skill_list
    @skill_group = skill_group
    @skill_cat = skill_cat
    @strains = strains
    @professions = professions
    @strain_stats = strain_stats
    @strain_specs = strain_specs

    validate_non_empty
    validate_skill_name_matches
    validate_stats
    validate_strain_specs
  end

private
  def validate_non_empty
    assert(@skill_list.length > 0, "Empty skill list")
    assert(@skill_cat.length > 0, "Empty processed skills")
    assert(@strains.length > 0, "Empty strains")
    assert(@professions.length > 0, "Empty professions")
  end

  def validate_strain_specs
    cumulative_strain_specs = Hash.new

    @strain_specs.each do |strain, specs|
      is_in_strain?(strain)
      specs[:advantages].concat(specs[:disadvantages]).each do |spec|
        assert(cumulative_strain_specs[spec] == nil,
               "Duplicate strain-specific skill: [#{strain}] [#{spec}]")

        cumulative_strain_specs[spec] = true
      end
    end
  end

  def validate_stats
    @strain_stats.each do |strain, stats|
      is_in_strain?(strain)
      assert(stats.keys.sort == [:hp, :mp, :infection].sort, 
             "Strain stats must contain HP, MP and Infection")
    end
  end

  def validate_skill_name_matches
    mismatches = Array.new
    @skill_cat.each do |skill_name, sdata|
      if !is_in_list?(skill_name)
        puts "mismatch: #{skill_name}"
        mismatches << skill_name
        ap @skill_cat[skill_name]
      end

      sdata.each do |stype, stdata|
        case stype
        when :innate, :innate_disadvantage
          stdata.each do |strain|
            is_in_strain?(strain)
          end
        when :innate_preq
        when :open
        else
          is_in_profession?(stype)
          if stdata[:preq]
            stdata[:preq][:list].each do |pskill, _junk|
              is_in_list?(pskill)
            end
          end
        end
      end
    end
  end

  def is_in_list? _x
    if @skill_list[_x] == nil && @skill_group[_x] == nil
      puts "mismatched skill: #{_x}"
      return false
    end
    return true
  end

  def is_in_strain? _x
    if !@strains.include?(_x)
      puts "mismatched strain: #{_x}"
      return false
    end
    return true
  end

  def is_in_profession? _x
    if !@professions.include?(_x)
      puts "mismatched profession: #{_x}"
      return false
    end
    return true
  end
end