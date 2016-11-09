require 'ap'
require 'trollop'
require_relative 'RawReader.rb'

opts = Trollop::options do
end

raw_reader = RawReader.new filepath: ARGV[0]