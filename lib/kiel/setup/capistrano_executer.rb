require 'yaml'

module Kiel
    OPTIONS = YAML.load STDIN 
    TAGS    = OPTIONS[ :tags ]
end    

Kiel::OPTIONS[ :capistrano_options ].each do | key, value |
    set key, value
end
    
role :server, Kiel::OPTIONS[ :capistrano_server ]

load Kiel::OPTIONS[ :script ]

task Kiel::OPTIONS[ :name ] do
    begin
        retry_count = 10
        
        begin 
            deploy.step
        rescue Capistrano::ConnectionError => ex
            raise unless ex.message =~ /Errno::ECONNREFUSED|Errno::ETIMEDOUT/

            puts "Connection failed"
            retry_count -= 1
            
            if retry_count == 0
                puts 'giving up...'
                raise
            end
            
            puts 'retrying...'
            sleep 15
            retry
        end            
    rescue Exception => ex
        puts ex.message
        puts ex.backtrace.join("\n")
        puts '+-+-+-+ERORR+-+-+-+'
    end        
end