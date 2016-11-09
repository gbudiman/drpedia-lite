require 'set'

class RawReader
  STATE_TRANSITION = {
    :undef      => { pattern: /== Advantage Skill ==/,    next: :innate },
    :innate     => { pattern: /== Open Skill ==/,         next: :open },
    :open       => { pattern: /==/,                       next: :profession },
    :profession => { pattern: /== Skill List ==/,         next: :list },
    :list       => { pattern: /./,                        next: :list }
  }

  def initialize filepath:
    f = nil
    @skill_list = Hash.new
    @skill_cat = Hash.new

    begin
      f = File.read(filepath)
    rescue Errno::ENOENT => e
      puts "File not found: #{filepath}"
      puts e.backtrace
      exit 1
    end

    split_by_sections(raw: f)

    ap @skill_list
    ap @skill_cat
  end

private
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
    if line =~ /== ([\w\s]+) ==/
      return $1.strip
    end
  end

  def execute_state_task state:, profession:, line:
    return if line =~ /==/

    case state
    when :innate then process_innate_skills line: line
    when :open then process_open_skills line: line
    when :profession then process_profession_skills line: line, profession: profession
    when :list then process_list_skills line: line
    end
  end

  def process_innate_skills line:
    innate_skill = line.split(/:/)
    strain = innate_skill[0]
    skills = innate_skill[1].split(/,/)

    smart_insert strain: strain, skills: skills
  end

  def process_open_skills line:
    line =~ /([\w\s]+)(\d+)/
    skill = $1.strip
    cost = $2.to_i

    smart_insert open_skills: { skill: skill, cost: cost }
  end

  def process_profession_skills line:, profession:
    line =~ /([\w\s]+)(\d+)(.+)/
    return unless $1

    skill = $1.strip
    cost = $2.to_i

    preq_string = $3
    preq_string =~ /([\|\&])/
    predicate = $1.strip if $1

    preq ||= { predicate: nil, list: Hash.new }
    preq_string.split(/[\|\&]/).each do |prerequisite|
      preq[:predicate] = predicate == '|' ? :or : :and
      preq[:list][prerequisite.strip] = true if prerequisite.strip.length > 0
    end

    smart_insert profession_skills: { skill: skill, profession: profession, cost: cost, preq: preq }
  end

  def process_list_skills line:
    @skill_list[line.strip.to_sym] = true
  end

  def smart_insert strain: nil, skills: nil, open_skills: nil, profession_skills: nil
    if strain and skills
      skills.each do |_skill|
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
      @skill_cat[profession_skills[:skill]] ||= Hash.new
      @skill_cat[profession_skills[:skill]][profession_skills[:profession].to_sym] = profession_skills[:cost]
    end
  end
end