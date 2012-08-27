
module Kiel
    module SCM
    
        # A mock, implementing the interface to a source code managment system
        class Mock
            def initialize versions = {}
                @versions = versions
            end
                            
            # returns the latest version of the given file 
            def version step
                step = step.to_s
                raise RuntimeError, "no mocked version for step \'#{step}\'" unless @versions.key? step
                @versions[ step ]
            end
            
            #--
            def versions hash
                @versions = hash
            end
        end
    end
end