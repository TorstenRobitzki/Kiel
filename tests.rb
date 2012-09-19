#--
require 'kiel'
require 'kiel/scm/mock'
require 'kiel/scm/git'
require 'kiel/cloud/mock'
require 'kiel/setup/mock'
require 'kiel/setup/capistrano'
require 'rake'
require 'yaml'

class Tests < MiniTest::Unit::TestCase

    # Mock for the source code management containing three elements having the versions 1, 2 and 3.
    # Mocks for excess to the cloud provider and an interface to setup a started cloud computer   
    def setup
        Kiel::set_defaults \
            scm: Kiel::SCM::Mock.new( '/application.rb' => '1', '/middle_ware.rb' => '2', '/base_image.rb' => '3', '*' => '1' ), 
            cloud: Kiel::Cloud::Mock.new( { id: 'image_provided_by_cloud_provider', tags: {} }  ), 
            setup: Kiel::Setup::Mock.new,
            base_image: 'image_provided_by_cloud_provider', root_dir: '/'
            
        @INITIAL_IMAGES = 1            
    end
    
    def teardown
        Rake::Task::clear
        Kiel::reset_defaults
    end
    
    def test_setting_defaults_will_result_in_only_the_given_defaults_changed
        Kiel::set_defaults setup: "Hallo" 
        
        assert_equal Kiel::defaults[ :scm ].class, Kiel::SCM::Mock
        assert_equal Kiel::defaults[ :cloud ].class, Kiel::Cloud::Mock
        assert_equal Kiel::defaults[ :setup ].class, String
    end
    
    def cloud
        Kiel::defaults[ :cloud ]
    end

    def test_tags_are_passed_to_the_setup
        Kiel::image [ :application, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke
        
        step = Kiel::defaults[ :setup ].last_step_data
        assert step
        assert step.key? :tags
        assert_equal( { 'image_type' => 'application', 'application' => '1', 'middle_ware' => '2', 'base_image' => '3' },
            step[ :tags ] )
    end 
    
    
    # make sure, that tasks are defined and that they depend on each other in the correct order
    def test_simple_image_definition 
        Kiel::image [ :application, :middle_ware, :base_image ]
    
        assert Rake::Task[ :application ]
        assert_equal Rake::Task[ :application ].prerequisites, [ 'middle_ware', 'base_image' ] 
        assert Rake::Task[ :middle_ware ]
        assert_equal Rake::Task[ :middle_ware ].prerequisites, [ 'base_image' ] 
        assert Rake::Task[ :base_image ]       
        assert_equal Rake::Task[ :base_image ].prerequisites, [] 
    end
    
    def test_steps_are_executed_in_order_right_to_left
        Kiel::image [ :application, :middle_ware, :base_image ]

        Rake::Task[ :application ].invoke  
        assert_equal Kiel::defaults[ :setup ].executed_steps, [ '/base_image.rb', '/middle_ware.rb', '/application.rb' ]  
    end
    
    def test_results_in_three_images
        Kiel::image [ :application, :middle_ware, :base_image ]

        Rake::Task[ :application ].invoke
        created_images = cloud.calls.find_all{ | call | call[ :func ] == :store_image }
        assert_equal 3, created_images.size, '3 images created'
        # one immage was already in the start set
        assert_equal 3 + @INITIAL_IMAGES, cloud.stored_images.size, '3 images created'
        
    end

    def test_at_the_end_there_is_no_instance_running
        Kiel::image [ :application, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke

        assert_equal cloud.running_instances, []
    end
    
    def test_if_the_base_image_is_already_there_it_will_not_be_executed
        Kiel::set_defaults cloud: Kiel::Cloud::Mock.new( 
            [ { id: 'image_provided_by_cloud_provider', tags: {} },
              { id: 'xxx', tags: { 'image_type' => 'base_image', 'base_image' => '3' } } ] ) 

        assert cloud.exists? 'image_type' => 'base_image', 'base_image' => '3' 

        Kiel::image [ :application, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke

        created_images = cloud.calls.find_all{ | call | call[ :func ] == :store_image }
        assert_equal 2, created_images.size, '2 images created'

        assert cloud.exists? 'image_type' => 'application', 'application' => '1', 'middle_ware' => '2', 'base_image' => '3'
        assert cloud.exists? 'image_type' => 'middle_ware', 'middle_ware' => '2', 'base_image' => '3' 
    end
    
    def test_if_middle_ware_description_updates_application_and_middle_ware_have_to_be_updated
        Kiel::image [ :application, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke

        Kiel::set_defaults \
            scm: Kiel::SCM::Mock.new( '/application.rb' => '1', '/middle_ware.rb' => '4', '/base_image.rb' => '3', '*' => '1' ) 
        
        Rake::Task::clear
        Kiel::image [ :application, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke

        assert cloud.exists? 'image_type' => 'application', 'application' => '1', 'middle_ware' => '2', 'base_image' => '3'
        assert cloud.exists? 'image_type' => 'middle_ware', 'middle_ware' => '2', 'base_image' => '3' 
        assert cloud.exists? 'image_type' => 'application', 'application' => '1', 'middle_ware' => '4', 'base_image' => '3'
        assert cloud.exists? 'image_type' => 'middle_ware', 'middle_ware' => '4', 'base_image' => '3' 
        assert cloud.exists? 'image_type' => 'base_image', 'base_image' => '3'         

        images = cloud.stored_images
        assert_equal 5 + @INITIAL_IMAGES, images.size
    end
    
    def test_tags_are_set_for_the_images
        refute cloud.exists? 'image_type' => 'application', 'application' => '1', 'middle_ware' => '2', 'base_image' => '3'
        refute cloud.exists? 'image_type' => 'middle_ware', 'middle_ware' => '2', 'base_image' => '3' 
        refute cloud.exists? 'image_type' => 'base_image', 'base_image' => '3' 

        Kiel::image [ :application, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke

        images = cloud.stored_images
        assert_equal 3 + @INITIAL_IMAGES, images.size
        
        assert cloud.exists? 'image_type' => 'application', 'application' => '1', 'middle_ware' => '2', 'base_image' => '3'
        assert cloud.exists? 'image_type' => 'middle_ware', 'middle_ware' => '2', 'base_image' => '3' 
        assert cloud.exists? 'image_type' => 'base_image', 'base_image' => '3' 
    end
    
    def test_the_version_of_the_first_element_is_by_default_determined_by_the_whole_repository
        Kiel::set_defaults \
            scm: Kiel::SCM::Mock.new( '/application.rb' => '1', '/middle_ware.rb' => '2', '/base_image.rb' => '3', '*' => '99' )

        Kiel::image [ :application, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke
        
        assert cloud.exists? 'image_type' => 'application', 'application' => '99', 'middle_ware' => '2', 'base_image' => '3'

        Kiel::set_defaults \
            scm: Kiel::SCM::Mock.new( '/application.rb' => '1', '/middle_ware.rb' => '2', '/base_image.rb' => '3', '*' => '42' ) 
        
        Rake::Task::clear
        Kiel::image [ :application, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke

        assert cloud.exists? 'image_type' => 'application', 'application' => '42', 'middle_ware' => '2', 'base_image' => '3'
    end    
    
    def test_the_version_of_the_first_element_is_not_determined_by_the_whole_repository_if_given
        Kiel::set_defaults \
            scm: Kiel::SCM::Mock.new( '/application.rb' => '19', '/middle_ware.rb' => '2', '/base_image.rb' => '3', '*' => '99' )

        Kiel::image [ { name: :application, scm_name: '/application.rb' }, :middle_ware, :base_image ]
        Rake::Task[ :application ].invoke
        
        assert cloud.exists? 'image_type' => 'application', 'application' => '19', 'middle_ware' => '2', 'base_image' => '3'
    end         
   
    def test_invalid_image_step_parameters_are_detected
        assert_raises( ArgumentError ) { Kiel::image [ { name: :application, barfasel: 12 }, :middle_ware, :base_image ] }
    end
    
    def test_missing_step_name_is_detected
        assert_raises( ArgumentError ) { Kiel::image [ { scm_name: :application }, :middle_ware, :base_image ] }
    end 
    
    def test_options_passed_to_image_are_used
        Kiel::image [ :application, :middle_ware, :base_image ],
            :scm => Kiel::SCM::Mock.new( '/application.rb' => '1', '/middle_ware.rb' => '2', '/base_image.rb' => '3', '*' => '42' )
        Rake::Task[ :application ].invoke
    
        # as now the :scm instance passed to the call to image was used, the version stored in the tag must be 42, not 1
        assert cloud.exists? 'image_type' => 'application', 'application' => '42', 'middle_ware' => '2', 'base_image' => '3'
        refute cloud.exists? 'image_type' => 'application', 'application' => '1', 'middle_ware' => '2', 'base_image' => '3'
    end
    
    def test_the_correct_setup_scripts_are_called
        Kiel::image [ 
            { :name => 'app', :task => :application, :scm_name => 'deployment.rb' },
            { :name => :middle_ware, :setup_name => 'install_middle_ware.perl' },
            :base ],
       :scm => Kiel::SCM::Mock.new( '/deployment.rb' => '1', '/middle_ware.rb' => '2', '/base.rb' => '3' )

        Rake::Task[ :application ].invoke
        
        assert_equal [ '/base.rb', '/install_middle_ware.perl', '/deployment.rb' ], Kiel::defaults[ :setup ].executed_steps 
    end
    
    def test_unrecognized_options_are_detected 
        assert_raises( ArgumentError ) { Kiel::image [ :application, :middle_ware, :base_image ], foobar: 1 } 
    end
    
    def test_description
        Kiel::image( [ { name: :application, description: 'foobar' }, :base_image ] )
    
        assert_equal 'foobar', Rake::Task[ :application ].comment
        assert Rake::Task[ :base_image ]
        refute Rake::Task[ :base_image ].comment
    end
end

class CloudMockTest < MiniTest::Unit::TestCase
    def setup 
        @cloud = Kiel::Cloud::Mock.new 'basic_image'
    end
    
    def test_stopping_a_never_started_instance_will_raise
        assert_raises( RuntimeError ) { @cloud.stop_instance 42 } 
    end        

    def test_saveing_the_image_of_a_not_running_image_will_raise
        assert_raises( RuntimeError ) { @cloud.store_image 42, { } }
    end
    
    def test_stopping_a_started_instance_will_not_raise
        instance = @cloud.start_instance id: 'basic_image' 
        @cloud.stop_instance instance 
        
        assert_raises( RuntimeError ) { @cloud.stop_instance instance }
    end
end

class SCMMockTest < MiniTest::Unit::TestCase
    def setup
        @scm = Kiel::SCM::Mock.new
    end
    
    def test_mock_with_raise_if_version_is_not_given
        assert_raises( RuntimeError ) { @scm.version 'foobar' } 
    end
end


class SCMGitTest < MiniTest::Unit::TestCase
    FILE_VERSIONS = [ 'da8cbc111aced3e2370fa060da0f7cde29bc1af3', 'bda861d3b27f7977f54165a2bdd0c43453b3a971', 'bd3b715449f9cd1f2c4c0ea70a3257d682cea959']

    def setup
        @git = Kiel::SCM::Git.new
    end
       
    def teardown
        Rake::Task::clear
        Kiel::reset_defaults
    end
             
    def test_ask_for_the_version_of_a_single_file
        assert_equal FILE_VERSIONS[ 0 ], @git.version( 'fixtures/root/application.rb' )
        assert_equal FILE_VERSIONS[ 1 ], @git.version( 'fixtures/root/middle_ware.rb' )
        assert_equal FILE_VERSIONS[ 2 ], @git.version( 'fixtures/root/base.rb' )
    end
    
    def test_ask_for_the_head_version
        refute FILE_VERSIONS.include? @git.version( '*' )
    end
    
    def test_ask_for_a_list_of_files
        a_b = @git.version( [ 'fixtures/root/application.rb','fixtures/root/middle_ware.rb' ] )
        b_a = @git.version( [ 'fixtures/root/middle_ware.rb','fixtures/root/base.rb' ] )
        a_c = @git.version( [ 'fixtures/root/application.rb','fixtures/root/base.rb' ] )
        
        refute_equal a_b, b_a
        refute_equal a_b, a_c
        refute_equal b_a, a_c
        
        refute FILE_VERSIONS.include? a_b
        refute FILE_VERSIONS.include? b_a
        refute FILE_VERSIONS.include? a_c
    end

    def test_if_multiple_files_are_given_the_order_should_not_matter
        assert_equal @git.version( [ 'fixtures/root/application.rb','fixtures/root/middle_ware.rb' ] ),
            @git.version( [ 'fixtures/root/middle_ware.rb', 'fixtures/root/application.rb' ] )
    end
    
    def test_git_is_the_default
        Kiel::set_defaults \
            cloud: Kiel::Cloud::Mock.new( { id: 'image_provided_by_cloud_provider', tags: {} }  ), 
            setup: Kiel::Setup::Mock.new,
            base_image: 'image_provided_by_cloud_provider', root_dir: File.expand_path( '../fixtures/root', __FILE__ )

        Kiel::image [ :application, :middle_ware, :base ]  
        Rake::Task[ :application ].invoke

        cloud = Kiel::defaults[ :cloud ]
        repo_version = @git.version '*'
        
        assert cloud.exists? 'image_type' => 'application', 
            'application' => repo_version, 'middle_ware' => FILE_VERSIONS[ 1 ], 'base' => FILE_VERSIONS[ 2 ]
        assert cloud.exists? 'image_type' => 'middle_ware', 
            'middle_ware' => FILE_VERSIONS[ 1 ], 'base' => FILE_VERSIONS[ 2 ] 
        assert cloud.exists? 'image_type' => 'base', 'base' => FILE_VERSIONS[ 2 ]       
    end
end

class SetupCapistranoTest < MiniTest::Unit::TestCase
    def setup
        teardown
        @capo = Kiel::Setup::Capistrano.new
    end

    def teardown
        begin; File.delete( File.expand_path( '../fixtures/capo_out.yml', __FILE__ ) ); rescue; end
    end

    # check to see that the script got executed                 
    def test_run_capo_script
        step = { setup_name: File.expand_path( '../fixtures/capo_script.rb', __FILE__ ), tags: { a:1, b:2 }, name: 'install' }
        @capo.execute step, 'localhost'
        result = YAML.load_file File.expand_path( '../fixtures/capo_out.yml', __FILE__ )
        
        assert_equal result, { tags: { a:1, b:2 } }
    end
end
