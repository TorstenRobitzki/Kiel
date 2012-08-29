require 'yaml'

namespace :deploy do

    # deploy:step is the steps default task
    task :step do
        puts "now writing the content of the received tags back: #{Kiel::TAGS.inspect}"
        
        File.open( File.expand_path( '../capo_out.yml', __FILE__ ) , 'w') do | file |
            file.write( YAML::dump( { tags: Kiel::TAGS } ) )
        end
    end
end    