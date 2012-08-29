require 'yaml'

module Kiel
    module Setup
        # The Capistrano Setup component executes one task out of a given script. The name of the script is by default
        # the name of step + '.rb' in the +:root_dir+ given to Kiel::image. The task to be executed is 'deploy:step'.
        # The tags that will be applied to the resulting image are passed to the script as global constant ::TAGS 
        class Capistrano

            # +options+ are passed directly to Capistrano:
            #   options.each { | key, value |
            #      set key, value 
            #   } 
            # so every options that have to be set in every script should be set by using this options.
            def initialize options = {}
                @options = options 
            end
            
            # step contains the whole step informations at least :setup_name contains the script to be executed, 
            # :tags contains the tags that will be added to the images after setup, :version contains the version of the
            # steps associated scm_name's file version. 
            def execute step, dns_server
                options = { script: step[ :setup_name ], tags: step[ :tags ], version: step[ :version ], 
                    name: step[ :name ].to_s, capistrano_options: @options, capistrano_server: dns_server }

                file = IO.popen( ['cap', '-f', File.expand_path( '../capistrano_executer.rb', __FILE__ ), step[ :name ].to_s ], 'r+' )

                file.write YAML::dump( options )
                file.close_write
                
                last_line = ''
                begin
                    begin
                        text = file.readpartial 1024
                        STDOUT.write text
                        last_line += text
                        last_line = last_line.split("\n").last
                    end until text.empty?
                rescue EOFError
                end                     
                
                raise "Error while executing #{step[ :setup_name ]}" if last_line =~ /\+-\+-\+-\+ERORR\+-\+-\+-\+/
            end
        end
    end
end