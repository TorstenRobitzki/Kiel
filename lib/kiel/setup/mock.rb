module Kiel
    module Setup
        class Mock
            def execute step
                @steps ||= []
                @steps << step
            end
            
            def executed_steps
                @steps || []
            end
        end
    end
end