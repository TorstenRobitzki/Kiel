
module Kiel
    module Cloud
    
        # Implementation of the Cloud access-Interface
        # The implementation assumes that a cloud provider provides machine images, used to start machines,
        # that this images can a not unique set of tags and a unique id. Where the id is provided by the cloud provider 
        # tags are provided by the user. Kiel used the tags to store version informations to an image and uses this 
        # set of tags to identify an image.
        #
        # The implementation assumes that a cloud provider allows to start a server with a machine image as parameter
        # and that the resulting instance has a public dns_name to be reachable.
        class Mock
            # +existing_images+ simulates an initial set of existing machine images, +dns_names+ provides a set of 
            # names that are assigned to newly created cloud instances.
            def initialize existing_images = [], dns_names = [] 
                @names = dns_names.dup
                @calls = [] 
                @images = [ existing_images.dup ].flatten
                @running = []
                @next_instance = 0
            end
            
            # starts a server instance in the cloud, returning a handle to that instance.
            # the image is either named by an image id +:id => 'image_id'+ or by a set of tags that match for
            # just one image +:tags => { 'image_type' => 'application', 'base' => '34' }+
            def start_instance image_name
                raise ArgumentError, "image_name must contain exactly one identification" unless image_name.size == 1

                @running << @next_instance
                @next_instance += 1
                @running.last
            end
            
            # store the given +instance+ under the given +image_name+ and add the hash of +tags+ to the image. 
            def store_image instance, tags
                image = { id: instance, tags: tags }
                @calls << { func: :store_image, args: image }
                @images << image
                stop_instance instance
            end
            
            # stops the given instance.
            def stop_instance instance
                unless @running.delete( instance ) 
                    raise RuntimeError, "there is no instance #{instance} running"
                end                    
            end

            # returns true, if an image with the given tags exists
            def exists? tags
                @images.detect { | image | image[ :tags ] == tags }
            end

            # returns the dns name from an instance
            def dns_name instance
                "#{instance}"
            end
            
            #--
            def calls
                @calls
            end 
            
            #--
            def running_instances
                @running
            end
            
            #--
            def stored_images
                @images 
            end
        end
    end
end