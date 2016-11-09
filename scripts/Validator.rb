class Validator
  def initialize skill_list:, skill_cat:
    @skill_list = skill_list
    @skill_cat = skill_cat
    validate_skill_name_matches
  end

private
  def validate_skill_name_matches
    mismatches = Array.new
    @skill_cat.each do |skill_name, sdata|
      if !is_in_list(skill_name)
        puts "mismatch: #{skill_name}"
        mismatches << skill_name
        ap @skill_cat[skill_name]
      end
    end
  end

  def is_in_list _x
    return @skill_list[_x] != nil
  end
end