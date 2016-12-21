require 'set'

class RawReader
  attr_reader :skill_list, :skill_cat, :skill_group, :advanced_cat,
              :strains, :strain_restrictions, :strain_stats, :strain_specs,
              :professions, :profession_concentrations, :profession_advanced

  STATE_TRANSITION = {
    :undef         => { pattern: /== Advantage Skill ==/,                 next: :innate },
    :innate        => { pattern: /== Disadvantage Skill ==/,              next: :strain_disadv },
    :strain_disadv => { pattern: /== Innate Skill Prerequisite ==/,       next: :innate_preq },
    :innate_preq   => { pattern: /== Profession Concentration ==/,        next: :prof_concent },
    :prof_concent  => { pattern: /== Advanced Profession ==/,             next: :adv_prof },
    :adv_prof      => { pattern: /== Advanced Profession Skills ==/,      next: :adv_skills },
    :adv_skills    => { pattern: /== Strain Profession Restriction ==/,   next: :strain_rtrs },
    :strain_rtrs   => { pattern: /== Strain Stats ==/,                    next: :strain_stats }, 
    :strain_stats  => { pattern: /== Strain Specific Skills ==/,          next: :strain_specs },
    :strain_specs  => { pattern: /== Open Skill ==/,                      next: :open },
    :open          => { pattern: /==/,                                    next: :profession },
    :profession    => { pattern: /== Skill Group ==/,                     next: :skill_group },
    :skill_group   => { pattern: /== Skill List ==/,                      next: :list },
    :list          => { pattern: /./,                                     next: :list }
  }

  def initialize filepath:
    f = nil
    @skill_list = Hash.new
    @skill_cat = Hash.new
    @advanced_cat = Hash.new
    @strains = Set.new
    @strain_restrictions = Hash.new
    @skill_group = Hash.new
    @strain_specs = Hash.new
    @strain_stats = Hash.new
    @professions = Set.new
    @profession_concentrations = Hash.new
    @profession_advanced = Hash.new

    @mutiline_state = nil

    begin
      f = File.read(filepath)
    rescue Errno::ENOENT => e
      puts "File not found: #{filepath}"
      puts e.backtrace
      exit 1
    end

    split_by_sections(raw: f)
    post_process_sets

    #ap @skill_cat
    #ap @advanced_cat
  end

private
  def post_process_sets
    @skill_cat.each do |_junk, data|
      data[:innate] = data[:innate].to_a
      data[:innate_disadvantage] = data[:innate_disadvantage].to_a
    end
  end

  def split_by_sections raw:
    state = :undef
    profession = :undef

    raw.split(/[\r\n]+/).each do |line|
      state, profession = detect_state_transition(current_state: state, current_profession: profession, line: line)
      execute_state_task state: state, profession: profession, line: line
    end
  end

  def detect_state_transition current_state:, current_profession:, line:
    profession = nil
    transition = STATE_TRANSITION[current_state]
    if transition[:pattern] =~ line
      if transition[:next] == :profession
        profession = extract_profession_name(line: line) || current_profession
      end
      return transition[:next], profession
    elsif current_state == :profession || current_state == :adv_skills
      profession = extract_profession_name(line: line) || current_profession
    end

    return current_state, profession
  end

  def extract_profession_name line:
    if line =~ /== ([\w\s\-]+) ==/
      return $1.strip.to_sym
    end
  end

  def execute_state_task state:, profession:, line:
    return if line =~ /==/

    case state
    when :innate then process_innate_skills line: line
    when :strain_disadv then process_innate_skills line: line, disadvantage: true
    when :innate_preq then process_innate_preqs line: line
    when :prof_concent then process_profession_concentration line: line
    when :adv_prof then process_advanced_professions line: line
    when :adv_skills then process_profession_skills line: line, profession: profession, type: :advanced
    when :strain_rtrs then process_strain_restrictions line: line
    when :strain_stats then process_strain_stats line: line
    when :strain_specs then process_strain_specs line: line
    when :open then process_open_skills line: line
    when :profession then process_profession_skills line: line, profession: profession
    when :skill_group then process_skill_group line: line
    when :list then process_list_skills line: line
    end
  end

  def process_innate_skills line:, disadvantage: false
    innate_skill = line.split(/:/)
    strain = innate_skill[0].to_sym
    skills = innate_skill[1].split(/,/)

    smart_insert strain: strain, skills: skills, disadvantage: disadvantage
  end

  def process_innate_preqs line:
    clusters = line.split(/:/)
    strain = clusters[0].strip.to_sym
    skill = clusters[1].strip.to_sym
    preqs = process_preq_cluster cluster: clusters[2]

    @skill_cat[skill][:innate_preq] ||= Hash.new
    @skill_cat[skill][:innate_preq][strain] = preqs
  end

  def process_strain_restrictions line:
    clusters = line.split(/:/)
    strain = clusters[0].strip.to_sym

    if !@strains.include?(strain)
      raise KeyError, "Can't add profession restriction to non-excisting strain: #{strain}"
    end

    @strain_restrictions[strain] ||= Hash.new
    clusters[1].split(/,/).each do |x| 
      @strain_restrictions[strain][x.strip.to_sym] = true
    end
  end

  def process_profession_concentration line:
    clusters = line.split(/:/)
    right_cluster = clusters[1].split(/\,/)

    @profession_concentrations[clusters[0].strip.to_sym] = right_cluster.collect{ |x| x.strip.to_sym }
  end

  def process_advanced_professions line:
    if line.strip.length == 0
      @multiline_state = nil
    else
      # Force whitespace at end to the length count is correct
      clusters = (line + ' ').split(/\:/)
      
      case clusters.length
      when 2
        @multiline_state = clusters[0].strip.to_sym
        @profession_advanced[@multiline_state] = ''

      when 1
        @profession_advanced[@multiline_state] += clusters[0]
      else
        raise RuntimeError, "#{clusters.length} clusters in multiline processing. Expected 1 or 2: #{line}"
      end
    end
  end

  def process_strain_specs line:
    clusters = line.split(/:/)
    right_cluster = clusters[1].split(/\|/)

    strain = clusters[0].strip.to_sym
    adv = Array.new
    dis = Array.new
    right_cluster[0].split(/\,/).each { |x| adv.push(x.strip.to_sym )}
    right_cluster[1].split(/\,/).each { |x| dis.push(x.strip.to_sym )}

    @strain_specs[strain] = {
      advantages: adv,
      disadvantages: dis
    }
  end

  def process_strain_stats line:
    clusters = line.split(/:/)
    right_cluster = clusters[1].split(/\,/)

    @strain_stats[clusters[0].strip.to_sym] = {
      hp: right_cluster[0].strip.to_i,
      mp: right_cluster[1].strip.to_i,
      infection: right_cluster[2].strip.to_i
    }
  end

  def process_skill_group line:
    @skill_group[line.strip.to_sym] = Hash.new
  end

  def process_open_skills line:
    line =~ /([\w\s\-\']+)(\d+)/
    skill = $1.strip.to_sym
    cost = $2.to_i

    smart_insert open_skills: { skill: skill, cost: cost }
  end

  def process_profession_skills line:, profession:, type: :basic
    line =~ /([A-Za-z\s\-\'\!\:\/]+)(\d+)(.*)/
    return unless $1

    skill = $1.strip.to_sym
    cost = $2.to_i
    preq = process_preq_cluster cluster: ($3 || '')

    smart_insert profession_skills: { skill: skill, 
                                      profession: profession, 
                                      cost: cost, 
                                      preq: preq },
                 type: type
  end

  def process_preq_cluster cluster:
    preq_string = cluster
    preq_string =~ /([\|\&])/
    predicate = $1.strip if $1

    preq ||= { predicate: nil, list: Hash.new }
    preq_string.split(/[\|\&]/).each do |prerequisite|
      preq[:predicate] = predicate == '|' ? :or : :and
      preq[:list][prerequisite.strip.to_sym] = true if prerequisite.strip.length > 0
    end

    if preq[:list].length == 0
      preq = nil
    end

    return preq
  end

  def process_list_skills line:
    skill_code = line[0..1]
    skill_clusters = line[3..-1].split(/\,/)
    skill_name = skill_clusters[0].strip.to_sym

    @skill_list[skill_name] = skill_code
    if skill_clusters[1]
      @skill_group[skill_clusters[1].strip.to_sym][skill_name] = true
    end
  end

  def smart_insert strain: nil, skills: nil, open_skills: nil, profession_skills: nil, disadvantage: false, type: nil
    if strain and skills
      @strains.add strain
      skills.each do |_skill|
        next if _skill.strip.length == 0
        skill = _skill.strip.to_sym
        @skill_cat[skill] ||= Hash.new
        @skill_cat[skill][:innate] ||= Set.new
        @skill_cat[skill][:innate_disadvantage] ||= Set.new

        if !disadvantage
          skill_cat_innate = @skill_cat[skill][:innate]
          skill_cat_innate.add strain.to_sym
        else
          skill_cat_innate = @skill_cat[skill][:innate_disadvantage]
          skill_cat_innate.add strain.to_sym
        end
      end
    elsif open_skills
      @skill_cat[open_skills[:skill]] ||= Hash.new
      @skill_cat[open_skills[:skill]][:open] = open_skills[:cost]
    elsif profession_skills
      skill = profession_skills[:skill]
      profession = profession_skills[:profession]
      cost = profession_skills[:cost]
      preq = profession_skills[:preq]
      professions.add profession

      case type
      when :basic
        @skill_cat[skill] ||= Hash.new
        @skill_cat[skill][profession] = {
          cost: cost,
          preq: preq
        }
      when :advanced
        @advanced_cat[skill] ||= Hash.new
        @advanced_cat[skill][profession] = {
          cost: cost,
          preq: preq
        }
      end

    end
  end
end