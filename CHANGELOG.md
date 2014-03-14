Changes
==

14 Mar 2014 (1.3.0)
--

Maintenance release that updates dependencies and **drops support for Ruby 1.9.2**.

As a result, less dependencies are now required.

CHANGES:

* Drop support for 1.9.2
* Add official support for 2.1.1
* Update dependencies (i.e., httparty)
* Remove some dependencies (i.e., Berkshelf & googl)

12 Feb 2014 (1.2.0)
--

FEATURES:

* Fallback to *knife.rb* for Chef Server configuration

FIXES:

* Detect when inspectors are not configured at all
* Blacklist metadata.rb's fields instead of using a whitelist
* Fix cache key for changelog

CHANGES:

* Show 'inspect' in help instead of 'investigate'

17 Dec 2013 (1.1.0)
--

FEATURES:

* Add option to recursively analyze cookbook's dependencies (defaults to true)
* Use a file to store configuration info (defaults to *${HOME}/.chef/kitchen_inspector.rb*)
* Add option to show remarks (*--remarks*), that now are hidden by default
* Add support for different Repository Managers (GitLab and GitHub)
* Verify that a tag on the Repository Manager matches the corresponding metadata's version
* Add exit codes to integrate Kitchen Inspector with a CI process
* Handle not unique projects on Repository Manager
* Analyze transitive dependencies even when Chef's version is null
* Show url to Repository Manager's diff whenever possible

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