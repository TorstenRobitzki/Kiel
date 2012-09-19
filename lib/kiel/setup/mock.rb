module Kiel
    module Setup
        class Mock
            def execute step, server
                @steps ||= []
                @steps << step[ :setup_name ]
                @last_step_data = step
            end
            
            def executed_steps
                @steps || []
            end
            
            def last_step_data
                @last_step_data
            end
        end
    end
end