require 'digest/sha1'

module Kiel
    module SCM
        class Git
            def single_version file
                result = `git rev-list --max-count 1 HEAD #{file}`
                result.gsub( /\n$/, '' )
            end
            
            private :single_version
            
            def version file
                files = [ file == '*' ? '' : file ].flatten
                return single_version( files.first ) if files.size == 1 

                files.sort.inject( '' ) { | sum, file | Digest::SHA1.hexdigest sum + single_version(file) }                
            end
        end
    end
end