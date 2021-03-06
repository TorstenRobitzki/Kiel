require 'digest/sha1'
require 'kiel/cloud/aws_base'

module Kiel
    module Cloud
        # Implements the connection to the Amazon Web Services (AWS). The current implementation works for one 
        # configured region. The default server is a small EC2 instance.
        class AWS
            include AWSBase
            
            RECOGNIZED_OPTIONS = [ :region, :credentials, :instance, :start_options ]
        
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

            # Finds all images where the given tags apply
            def all_images_by_tags tags
                images = @ec2.images.with_owner('self').tagged( tags.first.first )
    
                images = images.select do | image |
                    image_tags = image.tags.to_h
                    image_tags.merge( tags ) == image_tags 
                end
                
                images
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

            private :wait_for_ec2, :wait_for_image
            
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
                
                    puts "waiting 2 minutes before starting to take the image..."
                    sleep 120
                    puts "creating image..."
    
                    image = @ec2.images.create( 
                        :instance_id => instance.id,
                        :no_reboot => true,
                        :description => "automaticaly created #{tags[ 'image_type' ]} image",
                        :name => "#{tags[ 'image_type' ]} #{Digest::SHA1.hexdigest tags.inspect}" )
                       
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

            # the public dns name of the given instance
            def dns_name instance
                instance.dns_name
            end
            
            # deletes the given images by tags. For now this function is used just for cleanup during tests.
            def delete_image tags
                all_images_by_tags( tags ).each { | image | image.deregister } 
            end
        end
    end
end