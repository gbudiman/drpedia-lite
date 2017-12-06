require_relative 'drpedia_lite.rb'

skill_list = Builder.build(input: 'input/input.txt', 
                           base_output_path: 'output/')
# Builder.parse_rulebook(input1: 'input/part1.pdf', 
#                        input2: 'input/part2.pdf', 
#                        skill_list: skill_list, 
#                        base_output_path: 'output/')