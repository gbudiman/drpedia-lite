require 'test/unit/assertions'

class Validator
  include Test::Unit::Assertions
  def initialize skill_list:, skill_group:, skill_cat:, strains:, professions:
    @skill_list = skill_list
    @skill_group = skill_group
    @skill_cat = skill_cat
    @strains = strains
    @professions = professions

    validate_non_empty
    validate_skill_name_matches
  end

private
  def validate_non_empty
    assert(@skill_list.length > 0, "Empty skill list")
    assert(@skill_cat.length > 0, "Empty processed skills")
    assert(@strains.length > 0, "Empty strains")
    assert(@professions.length > 0, "Empty professions")
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
        when :innate
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