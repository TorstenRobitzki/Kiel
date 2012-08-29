module Kiel
    module Setup
        class Mock
            def execute step, server
                @steps ||= []
                @steps << step[ :setup_name ]
            end
            
            def executed_steps
                @steps || []
            end
        end
    end
end