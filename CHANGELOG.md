Changes
==
Next Version (1.x.x)
--

FEATURES:

* Add option to recursively analyze cookbook's dependencies (defaults to true)
* Use a file to store configuration info (defaults to *${HOME}/.chef/kitchen_inspector.rb*)
* Add option to show remarks (*--remarks*), that now are hidden by default
* Add support for different Repository Managers (but only Gitlab is supported at this stage)
* Verifies that a tag on the Repository Manager matches the corresponding metadata's version
* Add exit codes to integrate Kitchen Inspector with a CI process

FIXES:

* Handle case in which a given cookbook doesn't exist on both servers
* Grab information from Chef Server even when it's missing on the Repository Manager

18 Nov 2013 (1.0.1)
--

FIXES:

* Fix warnings retrieval and priorities

CHANGES:

* Add alias 'inspect'

15 Nov 2013 (1.0.0)
--

FEATURES:

* First release