MRuby::Gem::Specification.new('mruby-zurl') do |spec|
  spec.license = 'Apache-2'
  spec.author  = 'Hendrik Beskow'
  spec.summary = 'mruby zurl client'
  spec.add_dependency 'mruby-zmq'
  spec.add_dependency 'mruby-sysrandom'
  spec.add_dependency 'mruby-tnetstrings'
  spec.add_dependency 'mruby-sprintf'
end
