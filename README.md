Kiel
====

Kiel automates the process of creating rake tasks to produce Amazon Machine Images (AMI). The basic idea behind Kiel
is that an AMI can be best produced by installing software step by step on a defined base and by having all that 
steps under source code control. On the way from a base image to the final AMI, produces a new AMI with every step. 

Every task is associated with a single ruby script that will be executed
with Capistrano to setup a server started with the AMI produced by the previous task.  
Every AMI created by a task is tagged with all git versions of the scripts involved in creating that AMI.

Installation
------------

To install Kiel, download the source, cd into the source directory and use

>   rake gem
>   gem install kiel

to install the gem. Use `gem doc` to build the html documentation, use `gem tests` to run the tests.

Example
-------

>    Kiel::image [
>            { name: :application, description: 'build the application image' },
>            { name: :base_image, description: 'build the base image' },
>            :sioux, :boost, :ruby,
>            { name: :basics, scm_name: [ 'basics.rb', 'rakefile' ], setup_name: 'basics.rb' }
>        ],
>        { 
>            base_image: 'ami-6d555119', 
>            cloud: aws
>        }

creates 6 rake tasks, named application, base_image, sioux, boost, ruby and basics. Every task depends on all other
task following that task in the list of task. When starting the task `boost` for example, Kiel will determine the 
git versions of boost.rb, ruby.rb and basics.rb. Then Kiel will connect Amazon to look up the tags added to the 
AMIs for the 3 steps. If any of the AMIs tags do not fit with the git versions of the script, a new image will be
created and tagged.

Dependencies
------------
   - git command line client
   - Capistrano
   - AWS SDK
   - rake (of cause) 
   
Licence
-------

Kiel is licenced under MIT licence.