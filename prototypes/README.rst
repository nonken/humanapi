HumanApi Prototypes
===================

Summary
-------

This is a collection of prototypes for the HumanApi project.
They all showcase a usecase of the browser as a platform in use with
other non-standard components (e.g. hardware via bluetooth)

Prerequisites
-------------

Currently the HumanApi prototypes are based on PhoneGap (http://phonegap.com)
but any widget runtime can be used ultimately.

Get a copy of the PhoneGap repository from:

	git://github.com/phonegap/phonegap.git

Make sure that you follow ALL steps you find in the PhoneGap README and its
respective platforms (e.g. iphone/README). Make sure that all git submodules
are checked out correctly.

Prototype setup
---------------

Unless stated otherwise in the README in each prototypes directory follow these
steps to create a new PhoneGap based project for the prototype.

Basics
~~~~~~

All source files are located in the prototypes/src folder.
To test the prototype on a phone or simulator you need to create a dev project
using make.

Be aware that once you run make clean all projects in the prototypes/dev
folder get removed and eventual changes to the app code get lost. To prevent
this, create a branch and only edit code based in the prototypes/src directory.

prototypes/dev is primarily for testing!

Setup
~~~~~

	$ cd /prototypes/build

Now you can use make to create the project. Pass the projects name which is the
same as the directory in which the project is in as the second argument

e.g.

	$ make fridgeaid

If you want to create a new fresh project run following command first

	$ make clean

NOTE: this will delete all prior changes you might have made in all files and
folders except the www folder which is symlinked. As stated before,
don't edit code in the dev directory but only in the src directory

Now you can open the project in the editing environment for the device (e.g.
Xcode for iPhone applications). The project files are located in the
prototypes/dev/appname/device folder

Hardware setup
~~~~~~~~~~~~~~

Specific details for each applications can be found in the README of the
application.

More info
---------

Check humanapi.org for tutorials and more information.