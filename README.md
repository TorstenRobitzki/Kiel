Kiel
====

Kiel automates the process of creating rake tasks to produce Amazon Machine Images (AMI). The basic idea behind Kiel
is that an AMI can be best produced by installing software step by step on a defined base and by having all that 
steps under source code control. On the way from a base image to the final AMI, produces a new AMI with every step. 

Installation
------------

To install Kiel, download the source, change in the source directory and use

>   rake gem
>   gem install kiel

to install the gem. Use `gem doc` to build the html documentation, use `gem tests` to run the tests.

Licence
-------

Kiel is licenced under MIT licence.