require 'set'

class RawReader
  attr_reader :skill_list, :skill_cat, :skill_group, :advanced_cat, :concentration_cat,
              :strains, :strain_restrictions, :strain_stats, :strain_specs,
              :professions, :profession_concentrations, :profession_advanced,
              :profession_concentration_hierarchy, :profession_concentration_group,
              :profession_extension,
              :skill_counters, :skill_countered, :skill_mp_cost

  STATE_TRANSITION = {
    :undef         => { pattern: /== Advantage Skill ==/,                 next: :innate },
    :innate        => { pattern: /== Disadvantage Skill ==/,              next: :strain_disadv },
    :strain_disadv => { pattern: /== Disabled Innate Skill ==/,           next: :strain_block },
    :strain_block  => { pattern: /== Innate Skill Prerequisite ==/,       next: :innate_preq },
    :innate_preq   => { pattern: /== Profession Concentration ==/,        next: :prof_concent },
    :prof_concent  => { pattern: /== Concentration Hierarchy ==/,         next: :prof_hierarc },
    :prof_hierarc  => { pattern: /== Concentration Group ==/,             next: :conc_group },
    :conc_group    => { pattern: /== Profession Concentration Skills ==/, next: :conc_skills },
    :conc_skills   => { pattern: /== Advanced Profession ==/,             next: :adv_prof },
    :adv_prof      => { pattern: /== Advanced Profession Skills ==/,      next: :adv_skills },
    :adv_skills    => { pattern: /== Strain Profession Restriction ==/,   next: :strain_rtrs },
    :strain_rtrs   => { pattern: /== Strain Stats ==/,                    next: :strain_stats }, 
    :strain_stats  => { pattern: /== Strain Specific Skills ==/,          next: :strain_specs },
    :strain_specs  => { pattern: /== Open Skill ==/,                      next: :open },
    :open          => { pattern: /==/,                                    next: :profession },
    :profession    => { pattern: /== Skill Group ==/,                     next: :skill_group },
    :skill_group   => { pattern: /== Skill Counters ==/,                  next: :skill_counter },
    :skill_counter => { pattern: /== Profession Extension ==/,            next: :prof_ext },
    :prof_ext      => { pattern: /== Skill List ==/,                      next: :list },
    :list          => { pattern: /./,                                     next: :list }
  }

  def initialize filepath:
    f = nil
    @skill_list = Hash.new
    @skill_cat = Hash.new
    @advanced_cat = Hash.new
    @concentration_cat = Hash.new
    @strains = Set.new
    @strain_restrictions = Hash.new
    @skill_group = Hash.new
    @skill_counters = Hash.new
    @skill_countered = Hash.new
    @strain_specs = Hash.new
    @strain_stats = Hash.new
    @professions = Set.new
    @profession_concentrations = Hash.new
    @profession_advanced = Hash.new
    @profession_concentration_hierarchy = Hash.new
    @profession_concentration_group = Hash.new
    @profession_extension = Hash.new
    @skill_mp_cost = Hash.new

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
    #ap @profession_concentrations
    #ap @concentration_cat
    # ap @skill_counters
    # ap @skill_countered
    # ap @profession_concentration_group
    # ap @skill_list
    # ap @skill_mp_cost
  end

private
  def post_process_sets
    @skill_cat.each do |_junk, data|
      data[:innate] = data[:innate].to_a
      data[:innate_disadvantage] = data[:innate_disadvantage].to_a
      data[:innate_disabled] = data[:innate_disabled].to_a
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
    when :strain_block then process_innate_skills line: line, disabled: true
    when :innate_preq then process_innate_preqs line: line
    when :prof_concent then process_profession_concentration line: line
    when :prof_hierarc then process_profession_concentration_hierarchy line: line
    when :conc_group then process_profession_concentration_group line: line
    when :conc_skills then process_profession_concentration_skills line: line
    when :adv_prof then process_advanced_professions line: line
    when :adv_skills then process_profession_skills line: line, profession: profession, type: :advanced
    when :strain_rtrs then process_strain_restrictions line: line
    when :strain_stats then process_strain_stats line: line
    when :strain_specs then process_strain_specs line: line
    when :open then process_open_skills line: line
    when :profession then process_profession_skills line: line, profession: profession
    when :skill_group then process_skill_group line: line
    when :skill_counter then process_skill_counters line: line
    when :prof_ext then process_profession_extension line: line
    when :list then process_list_skills line: line
    end
  end

  def process_innate_skills line:, disadvantage: false, disabled: false
    innate_skill = line.split(/:/)
    strain = innate_skill[0].to_sym
    skills = innate_skill[1].split(/,/)

    smart_insert strain: strain, skills: skills, disadvantage: disadvantage, disabled: disabled
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

    right_cluster.each do |prof|
      @profession_concentrations[prof.strip.to_sym] = clusters[0].split(/\,/).collect{ |x| x.strip.to_sym }
    end
  end

  def process_profession_concentration_hierarchy line:
    clusters = line.split(/:/)
    right_cluster = clusters[1].split(/\,/)

    right_cluster.each do |prof|
      @profession_concentration_hierarchy[prof.strip.to_sym] = clusters[0].strip.to_sym
    end
  end

  def process_profession_concentration_group line:
    clusters = line.split(/:/)
    right_cluster = clusters[1].split(/\,/)

    @profession_concentration_group[clusters[0].strip.to_sym] = right_cluster.collect { |x| x.strip.to_sym }
  end

  def process_profession_concentration_skills line:
    clusters = line.split(/:/)

    # @concentration_cat[clusters[0].strip.to_sym] = clusters[1].split(/\,/).collect{ |x| x.strip.to_sym }

    clusters[1].split(/\,/).each do |skill|
      smart_insert profession_skills: { skill: skill.strip.to_sym,
                                        profession: clusters[0].strip.to_sym,
                                        cost: 0 },
                   type: :concentration
    end
  end

  def process_skill_counters line:
    segments = line.split(':')
    skill_name = segments[0].strip.to_sym
    subsegs = segments[1].strip.split('|')

    if subsegs[0].length > 0
      counters = subsegs[0].strip
      @skill_counters[skill_name] = counters.split(',').collect{ |x| x.strip.to_sym }
    end

    if subsegs[1]
      countered_by = subsegs[1].strip
      @skill_countered[skill_name] = countered_by.split(',').collect{ |x| x.strip.to_sym }
    end
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

  def process_profession_extension line:
    clusters = line.split(/:/)
    @profession_extension[clusters[0].strip.to_sym] = clusters[1].to_i
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
    # skill_code = line[0..1]
    # skill_clusters = line[3..-1].split(/\,/)
    # skill_name = skill_clusters[0].strip.to_sym

    # @skill_list[skill_name] = skill_code
    # if skill_clusters[1]
    #   @skill_group[skill_clusters[1].strip.to_sym][skill_name] = true
    # end
    line =~ /^([^\s]+)\s+([^\s]+)\s+(.*)$/
    skill_code = $1
    skill_mp_cost = $2
    skill_clusters = $3.split(/\,/)
    skill_name = skill_clusters[0].strip.to_sym

    @skill_list[skill_name] = skill_code
    @skill_mp_cost[skill_name] = skill_mp_cost
    if skill_clusters[1]
      @skill_group[skill_clusters[1].strip.to_sym][skill_name] = true
    end
  end

  def smart_insert strain: nil, skills: nil, open_skills: nil, profession_skills: nil, disadvantage: false, disabled: false, type: nil
    if strain and skills
      @strains.add strain
      skills.each do |_skill|
        next if _skill.strip.length == 0
        skill = _skill.strip.to_sym
        @skill_cat[skill] ||= Hash.new
        @skill_cat[skill][:innate] ||= Set.new
        @skill_cat[skill][:innate_disadvantage] ||= Set.new
        @skill_cat[skill][:innate_disabled] ||= Set.new

        if disadvantage
          @skill_cat[skill][:innate_disadvantage].add strain.to_sym
        elsif disabled
          @skill_cat[skill][:innate_disabled].add strain.to_sym
        else
          @skill_cat[skill][:innate].add strain.to_sym
        end
        # if !disadvantage
        #   if !disabled
        #     skill_cat_innate = @skill_cat[skill][:innate]
        #     skill_cat_innate.add strain.to_sym
        #   else
        #     skill_cat_innate_disabled = @skill_cat[skill][:innate_disabled]
        #     skill_cat_innate_disabled.add strain.to_sym
        #   end
        # else
        #   skill_cat_innate = @skill_cat[skill][:innate_disadvantage]
        #   skill_cat_innate.add strain.to_sym
        # end
      end
    elsif open_skills
      @skill_cat[open_skills[:skill]] ||= Hash.new
      @skill_cat[open_skills[:skill]][:open] = open_skills[:cost]
    elsif profession_skills
      skill = profession_skills[:skill]
      profession = profession_skills[:profession]
      cost = profession_skills[:cost]
      preq = profession_skills[:preq]
      

      case type
      when :basic
        professions.add profession
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
      when :concentration
        @concentration_cat[skill] ||= Hash.new
        @concentration_cat[skill][profession] = {
          cost: cost,
          preq: preq
        }
      end

    end
  end
end