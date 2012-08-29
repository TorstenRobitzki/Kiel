module Kiel
    module Cloud
        INSTANCE_STARTUP_TIMEOUT    = 120
        RECOGNIZED_OPTIONS = [ :region, :credentials, :instance, :start_options ]
        
        # Implements the connection to the Amazon Web Services (AWS). The current implementation works for one 
        # configured region. The default server is a small EC2 instance.
        class AWS
            # The contructor takes the following configuration options:
            #
            # :region:: A string naming the region to be used. If no region is given, the default region is used.
            #
            # :credentials:: A hash containing the fields 'access_key_id' and 'secret_access_key' with the credential
            #                information to your amazon account.
            #
            # :instance:: An instance of the AWS::EC2. If that instance is given, no +credentials:+ should be given.
            #             Kiel::Cloud::AWS will instead use this instance.     
            #
            # :start_options:: Options that are applied to EC2::InstanceCollection.create (siehe aws-sdk for more
            #                  details). The aws_tests.rb uses the :key_name and :security_groups options to set the
            #                  name of the used ssh key and a security group, where ssh is enabled.
            def initialize options = {}
                require 'aws/ec2'

                options.each_key do | key |
                    raise ArgumentError, "unrecognized option \'#{key}\'" unless RECOGNIZED_OPTIONS.include? key
                end
                                    
                @ec2 = options[ :instance ]
                @start_options = options[ :start_options ] || {}
                
                if @ec2 
                    puts "\'credentials\' ignored as an instance was given too" if options.key? :credentials
                else
                    ::AWS.config( options[ :credentials ]  )
    
                    @ec2 = ::AWS::EC2.new
                    @ec2 = @ec2.regions[ options[ :region ] ] if options.key? :region
                end
            end

            def all_images_by_tags tags
                images = @ec2.images.with_owner('self').tagged( tags.first.first )
    
                images = images.select do | image |
                    image_tags = image.tags.to_h
                    image_tags.merge( tags ) == image_tags 
                end
                
                images
            end    

            def image_by_tags tags
                images = all_images_by_tags tags
                
                raise "#{images.size} are tagged with the given tags: #{tags.inspect}" if images.size > 1 
                images.size == 1 ? images.first : nil 
            end
            
            def wait_for_ec2 instance
                puts "waiting for EC2 instance to start."
                sleep_count = INSTANCE_STARTUP_TIMEOUT
                while instance.status == :pending and sleep_count != 0 do 
                    sleep 1
                    sleep_count = sleep_count - 1
                end
            end

            def wait_for_image image
                image_state = :pending                              
                while image_state == :pending do
                    begin 
                        image_state = image.state
                    rescue => e
                        puts "err: #{e.inspect}"
                    end     
                       
                    sleep 1
                    STDOUT.write '.'
                end
                puts ''
            end

            private :image_by_tags, :wait_for_ec2, :wait_for_image
            
            # starts a server instance in the cloud, returning a handle to that instance.
            # the image is either named by an image id +:id => 'image_id'+ or by a set of tags that match for
            # just one image +:tags => { 'image_type' => 'application', 'base' => '34' }+
            def start_instance image_name
                options = @start_options.merge( if image_name.key?( :id ) 
                    { image_id: image_name[ :id ] }
                else
                    tags  = image_name[ :tags ]
                    image = image_by_tags tags
                    raise RuntimeError, "no image with tags: \'#{tags}\' found to start an instance" unless image
                    
                    { image_id: image.id }
                end )
                
                instance = @ec2.instances.create( options )
                
                begin
                    wait_for_ec2 instance
                    puts "ec2 instance \'#{instance.dns_name}\' started."
                rescue 
                    instance.terminate
                    raise
                end 
                
                instance
            end
            
            # store the given +instance+ and add the hash of +tags+ to the image. 
            def store_image instance, tags
                begin
                    image = @ec2.images.create( 
                        :instance_id => instance.id,
                        :no_reboot => true,
                        :description => "automaticaly created #{tags[ 'image_type' ]} image",
                        :name => tags[ 'image_type' ] )
                       
                    wait_for_image image
    
                    tags.each do | key, value |
                        image.add_tag( key, :value => value )
                    end               
                ensure
                    stop_instance instance
                end
            end
            
            # stops the given instance.
            def stop_instance instance
                begin
                    instance.terminate
                rescue
                end                    
            end

            # returns true, if an image with the given tags exists
            def exists? tags
                raise ArgumentError, "AWS.exists? with empty tags" if tags.empty?
                
                image_by_tags tags 
            end
            
            def dns_name instance
                instance.dns_name
            end
            
            # deletes the given image
            def delete_image image_name
            end
        end
    end
end