Gem::Specification.new do |s|
  s.name          = 'drpedia_lite'
  s.version       = '0.0.2'
  s.date          = Date.today
  s.summary       = 'Extracts data from Dystopia Rising handbook'
  s.description   = 'Extracts skills, strains, profession, and requirement trees into JSON'
  s.authors       = ['Gloria Budiman']
  s.email         = 'wahyu.g@gmail.com'
  s.files         = Dir.glob("lib/**/*.rb") + ['lib/input/input.txt']
  s.license       = 'MIT'
end