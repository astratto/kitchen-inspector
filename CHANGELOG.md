Changes
==
Next Version (1.1.0)
--

FEATURES:

* Add option to recursively analyze cookbook's dependencies (defaults to true)
* Use a file to store configuration info (defaults to *${HOME}/.chef/kitchen_inspector.rb*)
* Add option to show remarks (*--remarks*), that now are hidden by default
* Add support for different Repository Managers (GitLab and GitHub)
* Verifies that a tag on the Repository Manager matches the corresponding metadata's version
* Add exit codes to integrate Kitchen Inspector with a CI process
* Handle not unique projects on Repository Manager
* Analyze transitive dependencies even when Chef's version is null
* Shows url to Repository Manager's diff whenever possible

FIXES:

* Handle case in which a given cookbook doesn't exist on both servers
* Grab information from Chef Server even when it's missing on the Repository Manager
* Discard tags that are not versions (e.g., 'qa-latest')

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