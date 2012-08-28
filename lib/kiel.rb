require 'rake'
require 'kiel/scm/git'
require 'kiel/cloud/aws'

# Kiel tries to make the task to create cloud images easier by braking the whole installation into smaller, reproducible tasks.
# Each step is versioned by a version control system like git or subversion. Each installation step is described by a file
# containing a capistrano script. Kiel assumes that there is a specific order in which the steps have to be executed. 
#
# The purpose of splitting the installation of a machine image into smaller tasks is to save time when debugging the 
# installation and save time, when little changes have to be made to the installation. 
#  
# If one step fails, all subsequent installation steps might fail too. But when one step succeeds, that step can be
# used as base for all subsequence steps. 
#
# License::   Distributes under the MIT license

module Kiel
    #--
    RECOGNIZED_STEP_OPTIONS = [ :name, :task, :scm_name, :setup_name, :description ]
    DEFAULT_OPTIONS = {}
    RECOGNIZED_OPTIONS = [ :scm, :cloud, :setup, :base_image, :root_dir ]
     
    class Implementation
        def initialize defaults
            @defaults = defaults.dup
        end
        
        # this getters defer the construction of expensive devices to the latest moment possible
        def scm
            @defaults[ :scm ] ||= SCM::Git.new
        end
        
        def cloud
            @defaults[ :cloud ] ||= Cloud::AWS.new
        end
        
        def setup
            @defaults[ :setup ] 
        end 
    
        def expand_path file_name
            @defaults[ :root_dir ] ||= Dir.pwd
            File.expand_path file_name, @defaults[ :root_dir ]
        end
        
        def build_tags step, steps
            steps.inject( { 'image_type' => step[ :name ].to_s, step[ :name ].to_s => step[ :version ].to_s } ) do | t, s |
                 t.merge s[ :name ].to_s => s[ :version ].to_s
            end
        end
        
        def initial_image_id step, base_steps
            if base_steps.empty?
                unless @defaults.key? :base_image
                    raise ArgumentError, "no :base_image given. Need to know what the base image of the very first image to produce should be"
                end     
                { :id => @defaults[ :base_image ] }
            else         
                step, *steps = *base_steps        
                { :tags => build_tags( step, steps ) }
            end     
        end
    
        def create_task step, steps
            task = Rake::Task::define_task( step[ :task ] => steps.collect{ | s | s[ :task ] } ) do | task, arguments |
                tags = build_tags step, steps

                if cloud.exists? tags
                    puts "image \'#{step[ :name ]}\' already up to date and exists:"
                    tags.each{ | key, value | puts "\'#{key}\' => \'#{value}\'" }                    
                else
                    puts "starting instance for: \'#{step[ :name ]}\'"
                    instance = cloud.start_instance initial_image_id( step, steps )
                    puts "instance for: \'#{step[ :name ]}\' started."

                    begin
                        puts "excuting installation for: \'#{step[ :name ]}\'"
                        setup.execute expand_path( step[ :setup_name ] ) 
                        puts "installation for: \'#{step[ :name ]}\' done."

                        puts "storing image for: \'#{step[ :name ]}\'"
                        cloud.store_image instance, tags
                        puts "image for: \'#{step[ :name ]}\' stored"
                    rescue
                        cloud.stop_instance instance
                        raise
                    end                     
                end                     
            end

            task.add_description( step[ :description ] ) if step.key? :description
            task
        end
        
        def add_versions steps
            steps.collect() do | step | 
                name = step[ :scm_name ] == '*' ? '*' : expand_path( step[ :scm_name ] )
                step.merge( version: scm.version( name ) ) 
            end
        end

        private :setup, :cloud, :scm, :initial_image_id, :build_tags
    end
    
    # checks that all keys in options are valid
    def self.check_options options 
        options.each_key{ | key |
            raise ArgumentError, "Unrecognized option: \'#{key}\'" unless RECOGNIZED_OPTIONS.include? key
        }
    end
    
    def self.expand_steps steps
        raise ArgumentError, "no steps given" if steps.empty?
        
        # convert all steps to hashes and check the given parameters
        steps = steps.collect do | s; step |
            if s.respond_to? :to_hash
                step = s.to_hash.dup
                step.each { | key, value | 
                    raise ArgumentError, "unrecognized step option: \'#{key}\'" unless RECOGNIZED_STEP_OPTIONS.include? key
                }

                raise ArgumentError, "every step have to have at least a name" unless step.key? :name 

                step
            elsif s.respond_to? :to_s
                { :name => s.to_s }
            else
                raise ArgumentError, "a step have to be a string, symbol or a hash"
            end
        end

        steps.first[ :scm_name ] = '*' unless steps.first.key? :scm_name  

        # merge in defaults
        steps = steps.collect do | step |
            { 
                :task => step[ :name ], 
                :scm_name => "#{step[ :name ]}.rb"
            }.merge step
        end.collect do | step |
            {
                :setup_name => step[ :scm_name ] == '*' ? "#{step[ :name ]}.rb" : step[ :scm_name  ] 
            }.merge step
        end
        
        steps
    end

    # defines the +steps+ necessary to build an image by constructing Rake::Tasks that depend on each other. The 
    # dependencies are defined in the order the steps are given. Every step depends on all other steps following
    # that step in the list of given +steps+.
    #
    # Each step produces a new machine image, by starting a server in the cloud with the previous image,
    # adding a defined set of installation instructions and than saving the resulting image for the next step.
    # 
    # Every step is defined by hash with the following keys:
    #
    # :name:: The name of the step. The name is used to name a tag in the resulting image. The value of the tag is 
    #         the source code version of the sources of that step. By default +name+ is expanded to +name.rb+ in the
    #         current directory.
    #
    # :task:: The name of the Rake::Task to be created for that step. If not given, the +name+ is used.
    #
    # :scm_name:: The name that is passed to the source code management to determine the version of the description
    #             of the step. If not given, +name+ is expanded to +name.rb+ in the current directory. For the first
    #             element this defaults to '*', which is a special notation for the latest version of the repository.
    # 
    # :setup_name:: The name of the script to be executed. This defaults to :scm_name if given and not '*' or to 
    #               :name + '.rb' 
    #
    # :description:: Optional description for the task to be created.
    #
    # A step can be given by just one string or symbol, both following lines will result in the same images created.
    #    Kiel::image [ :stepA, :stepB ] 
    #    Kiel::image [ { :name => 'stepA', :task => 'stepA', :scm_name => '*', :setup_name ='stepA.rb' }, 
    #                  { :name => 'stepB', :task => 'stepB', :scm_name => 'stepB.rb' } ]
    #
    # +options+ is a set of configurations that can be used to override global options set by Kiel::set_defaults. 
    # Possible options are:
    #
    # :scm:: An instance of the +source code management+ used to retrieve version informations. By default this will
    #        be an instance of +Kiel::SCM::Git+.
    # 
    # :setup:: An instance of the device used to execute steps to execute the installations steps. By default this will
    #          be an instance of +Kiel::Setup::Capistrano+.
    # 
    # :cloud:: An instance of the cloud provider to lookup images and to access cloud instances. By default this will
    #          be an instance of +Kiel::Cloud::AWS+
    # 
    # :base_image:: A cloud image id that is used as base for the very first step. This is the right most argument in 
    #               the list of +steps+.
    # 
    # :root_dir:: Root directory, where all file names are bassed on. If the options is not given, the current directory is used
    #
    # Example:
    #    Kiel::image [ 'application', 'base' ], setup: Kiel::Setup::Capistrano.new, base_image: 'ami-6d555119'
    #
    # Will assume that every new version in the repository should lead to a new image based on an base image. The
    # layout of the base image is defined by base.rb and the base images is only recreated when the version of base.rb
    # changes. The base image is build by starting a cloud image with the id 'ami-6d555119'. To setup the base-image,
    # base.rb is executed by a newly created Kiel::Setup::Capistrano instance. The resulting base image will be stored
    # with the tags: 
    #    { 'image_type' => 'base', 'base' => '<version of base.rb>' }.
    #
    # An application image is build by starting a cloud server with the base image and executing the steps provided by
    # application.rb. The application image is then stored with the following tags:
    #    { 'iamge_type' => 'application', 'application' => '<version of the overall repository>, 'base' => '<version of base.rb>' }. 
    def self.image steps, options = {} 
        check_options( options ) 
        
        implemenation = Implementation.new defaults().merge( options )
        steps = expand_steps steps
        steps = implemenation.add_versions steps
        
        while !steps.empty? do
            step, *steps = *steps

            implemenation.create_task step.dup, steps.dup
        end
    end
    
    private_class_method :expand_steps, :check_options

    # set the global defaults that are applied to Kiel::image 
    def self.set_defaults defs
        check_options defs
        @@defaults ||= DEFAULT_OPTIONS.dup
        @@defaults.merge! defs
    end
     
    def self.reset_defaults
        @@defaults = nil
    end
            
    # returns the global defaults that are applied to every call to Kiel::image
    def self.defaults
        @@defaults ||= DEFAULT_OPTIONS.dup
        @@defaults
    end 
end
