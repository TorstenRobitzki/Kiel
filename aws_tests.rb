# The AWS tests are seperated, because an AWS account is needed to perform the tests
require 'kiel'
require 'kiel/scm/mock'
require 'kiel/cloud/aws'
require 'kiel/setup/mock'
require 'rake'
require 'yaml'

class CloudAWSTests < MiniTest::Unit::TestCase

    IMAGE_TAGS = [ 
        { 'image_type' => 'application', 'application' => '4', 'middle_ware' => '2', 'base' => '3' }, 
        { 'image_type' => 'middle_ware', 'middle_ware' => '2', 'base' => '3' }, 
        { 'image_type' => 'base', 'base' => '3' } ]
        
    def delete_all_images
        IMAGE_TAGS.each { | tags | @cloud.delete_image tags }
    end    
        
    def setup
        @cloud = Kiel::Cloud::AWS.new( YAML.load_file( 'aws.yml' ) )
        delete_all_images    
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
            base_image: 'ami-6d555119', root_dir: File.expand_path( '../fixtures/root', __FILE__ )

        Rake::Task[ :application ].invoke
        
        IMAGE_TAGS.each do | tags | 
            assert @cloud.exists?( tags ), "missing #{tags.inspect}" 
        end
    end
    
end
 
class CloudAWSOptionsTests < MiniTest::Unit::TestCase
    def test_that_unrecognized_options 
       assert_raises( ArgumentError ) { Kiel::Cloud::AWS.new( foo: :bar ) } 
    end
end