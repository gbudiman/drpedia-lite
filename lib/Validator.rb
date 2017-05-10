require 'test/unit/assertions'

class Validator
  include Test::Unit::Assertions
  def initialize skill_list:, 
                 skill_group:, 
                 skill_cat:, 
                 advanced_cat:,
                 concentration_cat:,
                 strains:, 
                 professions:, 
                 strain_stats:, 
                 strain_specs:,
                 profession_concentrations:,
                 profession_concentration_hierarchy:,
                 profession_concentration_group:,
                 profession_advanced:,
                 skill_counters:,
                 skill_countered:
    @skill_list = skill_list
    @skill_group = skill_group
    @skill_cat = skill_cat
    @advanced_cat = advanced_cat
    @concentration_cat = concentration_cat
    @strains = strains
    @professions = professions
    @strain_stats = strain_stats
    @strain_specs = strain_specs
    @profession_concentrations = profession_concentrations
    @profession_concentration_hierarchy = profession_concentration_hierarchy
    @profession_advanced = profession_advanced
    @skill_counters = skill_counters
    @skill_countered = skill_countered

    @profession_concentration_inverted = Hash.new
    @profession_concentrations.each do |basic, data|
      data.each do |conc|
        @profession_concentration_inverted[conc] = true
      end
    end

    validate_non_empty
    validate_skill_name_matches cat: @skill_cat
    validate_skill_name_matches cat: @advanced_cat
    validate_skill_name_matches cat: @concentration_cat
    validate_stats
    validate_strain_specs
    validate_profession_concentrations
    validate_profession_concentration_hierarchy
    validate_profession_advanced
    validate_non_duplicate_skill_codes
    validate_skill_counters cat: @skill_counters
    validate_skill_counters cat: @skill_countered
    validate_skill_counter_bidirectional
  end

private
  def validate_profession_concentrations
    assert(@profession_concentrations.length > 0)
  end

  def validate_profession_advanced
    assert(@profession_advanced.length > 0)
  end

  def validate_profession_concentration_hierarchy
    @profession_concentration_hierarchy.each do |prof, pc|
      is_in_profession?(prof)
    end
  end

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
      (specs[:advantages] + specs[:disadvantages]).each do |spec|
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

  def validate_skill_name_matches cat:
    mismatches = Array.new

    cat.each do |skill_name, sdata|
      if !is_in_list?(skill_name)
        # puts "mismatch: #{skill_name}"
        mismatches << skill_name
        # ap @skill_cat[skill_name]
      end

      sdata.each do |stype, stdata|
        case stype
        when :innate, :innate_disadvantage, :innate_disabled
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

  def validate_non_duplicate_skill_codes
    existing_codes = Hash.new

    @skill_list.each do |skill, code|
      if existing_codes[code] == nil
        existing_codes[code] = skill
      else
        puts "Duplicate skill code: #{code}"
        puts "  Previously claimed by: #{existing_codes[code]}"
        puts "  Ateempt to claim by:   #{skill}"
      end
    end
  end

  def validate_skill_counters cat:
    cat.each do |s, ls|
      if !is_in_list?(s)
        puts "Mismatched skill counter: #{s}"
      end

      ls.each do |l|
        if !is_in_list?(l)
          puts "Mismatched skill counter member: #{l}"
        end
      end
    end
  end

  def validate_skill_counter_bidirectional
    @skill_counters.each do |skill_name, counters|
      counters.each do |counter|
        if !has_interaction? skill: skill_name, counter: counter, interaction: :a_counters_b
          puts "Missing: skill #{skill_name} counters #{counter}, but skill #{counter} is not countered by #{skill_name}"
        end
      end
    end

    @skill_countered.each do |skill_name, countereds|
      countereds.each do |countered|
        if !has_interaction? skill: skill_name, counter: countered, interaction: :a_countered_by_b
          puts "Missing: skill #{skill_name} is countered by #{countered}, but skill #{countered} does not counter #{skill_name}"
        end
      end
    end
  end

  def has_interaction? skill:, counter:, interaction:
    case interaction
    when :a_counters_b
      return true if @skill_countered[counter] && @skill_countered[counter].include?(skill)
    when :a_countered_by_b
      return true if @skill_counters[counter] && @skill_counters[counter].include?(skill)
    end

    return false
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
    if !@professions.include?(_x) && 
       !@profession_advanced.keys.include?(_x) &&
       !@profession_concentration_inverted.keys.include?(_x)
      puts "mismatched profession: #{_x}"
      return false
    end
    return true
  end
end