Gem::Specification.new do | gem |
    gem.name     = 'kiel'
    gem.version  = '0.0'
    gem.date     = Date.today.to_s
    
    gem.summary  = 'Building cloud images step by step'
    gem.description = 'Helper to build rake task to build cloud images step by step for easier debugging and testing'

    gem.homepage = 'https://github.com/TorstenRobitzki/Kiel'
    gem.email    = 'gemmaster@robitzki.de'
    gem.author   = 'Torsten Robitzki'
    
    gem.licenses = ["MIT"]
    gem.files = Dir[ 'lib/**/*' ]
end