Gem::Specification.new do | gem |
    gem.name     = 'kiel'
    gem.version  = '0.2'
    gem.date     = Date.today.to_s
    
    gem.summary  = 'Building cloud images step by step'
    gem.description = <<-EOD
Kiel automates the process of creating rake tasks to produce Amazon Machine Images (AMI). The basic idea behind Kiel
is that an AMI can be best produced by installing software step by step on a defined base and by having all that 
steps under source code control. On the way from a base image to the final AMI, produces a new AMI with every step.
EOD
 
    gem.homepage = 'https://github.com/TorstenRobitzki/Kiel'
    gem.email    = 'gemmaster@robitzki.de'
    gem.author   = 'Torsten Robitzki'
    
    gem.add_dependency [ 'aws-sdk', 'capistrano' ]
    gem.licenses = ["MIT"]
    gem.files = Dir[ 'lib/**/*' ]
end