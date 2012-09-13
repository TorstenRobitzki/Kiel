module Kiel
    module Cloud
        module AWSBase
            INSTANCE_STARTUP_TIMEOUT    = 120

            def image_by_tags tags
                images = all_images_by_tags tags

                raise "#{images.size} are tagged with the given tags: #{tags.inspect}" if images.size > 1 
                images.size == 1 ? images.first : nil 
            end
    
            private :image_by_tags

            # returns true, if an image with the given tags exists
            def exists? tags
                raise ArgumentError, "AWS.exists? with empty tags" if tags.empty?
                
                image_by_tags tags 
            end
        end
    end
end