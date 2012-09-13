# The AWS tests are seperated, because an AWS account is needed to perform the tests
require 'kiel'
require 'kiel/scm/mock'
require 'kiel/cloud/aws'
require 'kiel/cloud/right_aws'
require 'kiel/setup/mock'
require 'rake'
require 'yaml'

EXISTING_BASE_IMAGE_NAME = 'ami-6d555119'

# expects @cloud to be a cloud provider or something to be called that will provide a provider
# expects cloud() to return a cloud provider
module Tests

    IMAGE_TAGS = [ 
        { 'image_type' => 'application', 'application' => '4', 'middle_ware' => '2', 'base' => '3' }, 
        { 'image_type' => 'middle_ware', 'middle_ware' => '2', 'base' => '3' }, 
        { 'image_type' => 'base', 'base' => '3' } ]
        
    def delete_all_images
        IMAGE_TAGS.each { | tags | cloud.delete_image tags }
    end    
        
    def teardown
        delete_all_images    
    end
    
    def test_create_three_images
        Kiel::set_defaults \
            scm: Kiel::SCM::Mock.new( 
                        File.expand_path( '../fixtures/root/application.rb', __FILE__ ) => '1', 
                        File.expand_path( '../fixtures/root/middle_ware.rb', __FILE__ ) => '2', 
                        File.expand_path( '../fixtures/root/base.rb', __FILE__ ) => '3', 
                        '*' => '4' ),
            setup: Kiel::Setup::Mock.new,
            cloud: @cloud
            
        Kiel::image [ :application, :middle_ware, :base ], 
            base_image: EXISTING_BASE_IMAGE_NAME, root_dir: File.expand_path( '../fixtures/root', __FILE__ )

        Rake::Task[ :application ].invoke
        
        IMAGE_TAGS.each do | tags | 
            assert cloud.exists?( tags ), "missing #{tags.inspect}" 
        end
    end
    
end
=begin # AWS and RightAWS together causes Internal Errors on the AWS side
class AWSTests < MiniTest::Unit::TestCase
    include Tests

    def setup
        @cloud = Kiel::Cloud::AWS.new( YAML.load_file( 'aws.yml' ) )
        delete_all_images    
    end
    
    def cloud
        @cloud 
    end
end    
 
class AWSOptionsTests < MiniTest::Unit::TestCase
    def test_that_unrecognized_options 
       assert_raises( ArgumentError ) { Kiel::Cloud::AWS.new( foo: :bar ) } 
    end
end
=end
class RightAWSTests < MiniTest::Unit::TestCase
    include Tests

    # the second time, the test(s) in Tests are performed, the deferred cloud connection construction is used
    def setup
        @cloud = lambda{ Kiel::Cloud::RightAWS.new( YAML.load_file( 'aws.yml' ) ) }
    end
    
    def cloud
        @the_cloud ||= @cloud.call
    end
    
    def test_start_stop_server
        skip 'very basic tests that is covered by test_create_three_images too'       
        instance = cloud.start_instance( { :id => EXISTING_BASE_IMAGE_NAME } )
        assert instance
        
        identifiying_tags = { 'a' => '1', 'b' => '2' }
        cloud.store_image instance, identifiying_tags
        assert cloud.exists? identifiying_tags 

        cloud.delete_image identifiying_tags 
        refute cloud.exists? identifiying_tags 

        cloud.stop_instance instance
    end
end

class RightAWSOptionsTests < MiniTest::Unit::TestCase
    def test_no_credentionals_no_cookies
        assert_raises( ArgumentError ) { Kiel::Cloud::RightAWS.new() }
    end
end
 
 