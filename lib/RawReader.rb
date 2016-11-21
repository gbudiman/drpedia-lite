require 'set'

class RawReader
  attr_reader :skill_list, :skill_cat, :strains, :professions, :strain_restrictions, :skill_group
  STATE_TRANSITION = {
    :undef        => { pattern: /== Advantage Skill ==/,                 next: :innate },
    :innate       => { pattern: /== Innate Skill Prerequisite ==/,       next: :innate_preq },
    :innate_preq  => { pattern: /== Strain Profession Restriction ==/,   next: :strain_rtrs },
    :strain_rtrs  => { pattern: /== Open Skill ==/,                      next: :open }, 
    :open         => { pattern: /==/,                                    next: :profession },
    :profession   => { pattern: /== Skill Group ==/,                      next: :skill_group },
    :skill_group  => { pattern: /== Skill List ==/,                     next: :list },
    :list         => { pattern: /./,                                     next: :list }
  }

  def initialize filepath:
    f = nil
    @skill_list = Hash.new
    @skill_cat = Hash.new
    @strains = Set.new
    @strain_restrictions = Hash.new
    @skill_group = Hash.new
    @professions = Set.new

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
  end

private
  def post_process_sets
    @skill_cat.each do |_junk, data|
      data[:innate] = data[:innate].to_a
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
    elsif current_state == :profession
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
    when :innate_preq then process_innate_preqs line: line
    when :strain_rtrs then process_strain_restrictions line: line
    when :open then process_open_skills line: line
    when :profession then process_profession_skills line: line, profession: profession
    when :skill_group then process_skill_group line: line
    when :list then process_list_skills line: line
    end
  end

  def process_innate_skills line:
    innate_skill = line.split(/:/)
    strain = innate_skill[0].to_sym
    skills = innate_skill[1].split(/,/)

    smart_insert strain: strain, skills: skills
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

  def process_skill_group line:
    @skill_group[line.strip.to_sym] = Hash.new
  end

  def process_open_skills line:
    line =~ /([\w\s\-\']+)(\d+)/
    skill = $1.strip.to_sym
    cost = $2.to_i

    smart_insert open_skills: { skill: skill, cost: cost }
  end

  def process_profession_skills line:, profession:
    line =~ /([\w\s\-\'\!\:\/]+)(\d+)(.*)/
    return unless $1

    skill = $1.strip.to_sym
    cost = $2.to_i
    preq = process_preq_cluster cluster: ($3 || '')

    smart_insert profession_skills: { skill: skill, profession: profession, cost: cost, preq: preq }
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

  def smart_insert strain: nil, skills: nil, open_skills: nil, profession_skills: nil
    if strain and skills
      @strains.add strain
      skills.each do |_skill|
        next if _skill.strip.length == 0
        skill = _skill.strip.to_sym
        @skill_cat[skill] ||= Hash.new
        @skill_cat[skill][:innate] ||= Set.new
        skill_cat_innate = @skill_cat[skill][:innate]

        skill_cat_innate.add strain.to_sym
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

      @skill_cat[skill] ||= Hash.new
      @skill_cat[skill][profession] = {
        cost: cost,
        preq: preq
      }

    end
  end
end