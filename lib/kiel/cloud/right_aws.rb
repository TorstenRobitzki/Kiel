require 'kiel/cloud/aws_base'

module Kiel
     module Cloud
        # Implements the connection to the Amazon Web Services (AWS) using the Right-AWS gem.
        class RightAWS
            include AWSBase
            
            RECOGNIZED_OPTIONS = [ :region, :credentials, :instance, :start_options ]

            # The contructor takes the following configuration options:
            #
            # :region:: A string naming the region to be used. If no region is given, North America is used by default.
            #
            # :credentials:: A hash containing the fields 'access_key_id' and 'secret_access_key' with the credential
            #                information to your amazon account.
            #
            # :instance:: An instance of the AWS::EC2. If that instance is given, no +credentials:+ should be given.
            #             Kiel::Cloud::AWS will instead use this instance.     
            #
            # :start_options:: Possible options are :key_name and :security_groups to set the
            #                  name of the used ssh key and a security group, where ssh is enabled.
            def initialize options = {}
                require 'right_aws'

                options.each_key do | key |
                    raise ArgumentError, "unrecognized option \'#{key}\'" unless RECOGNIZED_OPTIONS.include? key
                end
                                    
                @ec2 = options[ :instance ]
                @start_options = options[ :start_options ] || {}
                
                if @ec2 
                    puts "\'credentials\' ignored as an instance was given too" if options.key? :credentials
                else
                    raise ArgumentError, 'no credentials given' unless options.key? :credentials
                    credentials = options[ :credentials ]
                    
                    raise ArgumentError, 'no :access_key_id given within credentials' unless credentials.key? :access_key_id
                    raise ArgumentError, 'no :secret_access_key given within credentials' unless credentials.key? :secret_access_key         

                    params = options.key?( :region ) ? { region: options[ :region ] } : {} 
                    @ec2 = RightAws::Ec2.new credentials[ :access_key_id ], credentials[ :secret_access_key ], params
                end
            end
                    
            # Finds all images where the given tags apply
            def all_images_by_tags tags
                images = @ec2.describe_images_by_owner 'self'

                images = images.select do | image |
                    image_tags = image[ :tags ]
                    image_tags.merge( tags ) == image_tags 
                end
                
                images
            end

            def wait_for_ec2 instance
                puts "waiting for EC2 instance to start."
                sleep 10 # added to reduce the likelihood of getting an "The instance ID 'i-xxxxxx' does not exist" message 
                sleep_count = INSTANCE_STARTUP_TIMEOUT
                while @ec2.describe_instances( [ instance[ :aws_instance_id ] ] )[ 0 ][ :aws_state ] == 'pending' and sleep_count != 0 do 
                    sleep 1
                    sleep_count = sleep_count - 1
                end
            end

            def wait_for_image image
                image_state = 'pending'                              
                while image_state == 'pending' do
                    begin 
                        image_state = @ec2.describe_images_by_owner( 'self' ).detect{ | desc | desc[ :aws_id ] == image }
                        image_state = image_state[ :aws_state ]
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
                    
                    { image_id: image[ :aws_id ] }
                end )
                
                instance = @ec2.launch_instances( 
                    options[ :image_id ], image_id: options[ :image_id ], key_name: options[ :key_name ], group_names: options[ :security_groups ] )
                instance = instance[ 0 ]
                                
                begin
                    wait_for_ec2 instance
                    puts "ec2 instance \'#{dns_name instance}\' started."
                rescue 
                    stop_instance instance
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

                    image = @ec2.create_image( 
                        instance[ :aws_instance_id ],
                        :no_reboot => true,
                        :description => "automaticaly created #{tags[ 'image_type' ]} image",
                        :name => "#{tags[ 'image_type' ]} #{Digest::SHA1.hexdigest tags.inspect}" )
                       
                    puts "waiting for image to get ready..."
                    wait_for_image image

                    puts "image was created, adding tags..."
                    @ec2.create_tags( image, tags )
                    puts "tags added."
                ensure
                    stop_instance instance
                end
            end

            # stops the given instance.
            def stop_instance instance
                @ec2.terminate_instances( [ instance[ :aws_instance_id ] ] )
            end

            # the public dns name of the given instance
            def dns_name instance
                @ec2.describe_instances( [ instance[ :aws_instance_id ] ] )[ 0 ][ :dns_name ]
            end
            
            # deletes the given images by tags. For now this function is used just for cleanup during tests.
            def delete_image tags
                all_images_by_tags( tags ).each do | image | 
                    @ec2.deregister_image image[ :aws_id ]
                end     
            end
        end
    end
end