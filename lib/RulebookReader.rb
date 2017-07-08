require 'set'
require 'pdf-reader'

class RulebookReader
  @reader1 = nil
  @reader2 = nil
  @descs = {}
  

  def initialize input1:, input2:
    @reader1 = PDF::Reader.new(input1)
    @reader2 = PDF::Reader.new(input2)
    @descs = {}
    @lut = {
      'Animal Handler': 'Animal Handler I',
      'Bartender’s Tongue': 'Bartender\'s Tongue',
      'Big Dig': 'Big Dig I',
      'Call the All Mighty': 'Call The Almighty',
      'Fade in a Crowd': 'Fade In A Crowd',
      'Guild Member': 'Guild Membership',
      'Hunter’s Mark': 'Hunter\'s Mark',
      'Improved Pistol/Bow/Thrown/Javelin': 'Income I',
      'Melee Weapon, Large': 'Melee Weapon - Large',
      'Melee Weapon, Small': 'Melee Weapon - Small',
      'Melee Weapon, Standard': 'Melee Weapon - Standard',
      'Melee Weapon, Two Handed': 'Melee Weapon - Two Handed',
      'Throwing, Javelins': 'Throwing - Javelins',
      'Tie Bonds': 'Tie Binds',
      'Lore - Strain - Geijian': 'Lore - Stain - Genjian'
    }
  end

  def parse
    parse_basic_and_lores @reader1.pages[157..199]
    parse_basic_and_lores @reader1.pages[203..217]

    return self
  end

  def parse_basic_and_lores pages
    state = nil
    latch = Array.new

    pages.each do |page|
      lines = page.text.split(/[\n]+/)
      lines.each do |line|
        if line =~ /([^\(]+)\(MP/ or line.strip =~ /^(Lore [-–] .+)/
          captured = $1.gsub(/\:/, ' -').strip.to_sym
          rectified = captured
          if @lut[captured] != nil
            rectified = @lut[captured].to_sym
          end

          @descs[rectified] = ''
          @descs[state] = latch.join(' ')
          state = rectified
          latch = Array.new
        else
          if state != nil
            if line.strip =~ /^\d+$/ or line.strip =~ /^Madison Harris/
            else
              #latch +=  + "\n"
              latch.push line.gsub(/[\ ]{2,}/, ' ').strip
            end
          end
        end
      end
    end

    @descs[state] = latch.join(' ')
  end

  def crosscheck skill_list
    master_list = Set.new skill_list.keys
    desc_list = Set.new @descs.keys

    intersection = master_list & desc_list
    remainder = desc_list - intersection
    other = master_list - intersection

    ap remainder
    ap other
    dump_parsed
  end

  def dump_parsed
    @descs.each do |skill_name, desc|
      puts '--------------------'
      puts skill_name
      puts '--------------------'
      puts desc
    end
  end
end