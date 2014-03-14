# Kitchen Inspector
[![Build Status](https://travis-ci.org/astratto/kitchen-inspector.png?branch=master)](https://travis-ci.org/astratto/kitchen-inspector)
[![Dependency Status](https://gemnasium.com/astratto/kitchen-inspector.png)](https://gemnasium.com/astratto/kitchen-inspector)
[![Gem Version](https://badge.fury.io/rb/kitchen-inspector.png)](http://badge.fury.io/rb/kitchen-inspector)
[![Code Climate](https://codeclimate.com/github/astratto/kitchen-inspector.png)](https://codeclimate.com/github/astratto/kitchen-inspector)
[![Coverage Status](https://coveralls.io/repos/astratto/kitchen-inspector/badge.png)](https://coveralls.io/r/astratto/kitchen-inspector)

Kitchen Inspector is a CLI utility to check a cookbook's dependency status using a Chef server and a Repository Manager.

In particular, this tool checks whether the dependencies specified in a cookbook's metadata are up to date or not.
It also shows whether one of the servers must be aligned.

By default, dependencies are recursively analyzed and transitive dependencies are shown indented.

It assumes that your kitchen is composed by:

* a Chef server containing the cookbooks to be used
* a Repository Manager hosting cookbook's development

**Note:** at this stage GitLab and GitHub are supported.

## Installation

Install it from RubyGems.org with:

```bash
$ gem install kitchen-inspector
```

Or with Rake:

```bash
[kitchen-inspector_clone_dir]$ rake install
```

Repository Managers are loaded dynamically, so you should also install specific gems.

If you plan to use Kitchen Inspector with:

* GitHub: ```gem install octokit```
* GitLab: ```gem install gitlab```

## Usage

A valid configuration must be provided in order to configure the Chef Server and the Repository Manager.  
See [Configuration](#configuration) for details.

From inside the cookbook's directory, type `kitchen-inspector` to inspect your kitchen.
It's also possible to specify a target directory with `kitchen-inspector inspect PATH`.

Cookbook's `metadata.rb` is parsed to obtain the dependencies, then the configured Chef server and Repository Manager are queried to define which versions are available.  
**Note:** The Chef server's version is the one that defines the used version.

When a usable version is not found, Repository Manager's latest tag is used to analyze transitive dependencies.

It will display a table that contains the following rows:

* `Name` - The name of the cookbook
* `Requirement` - The version requirement specified in the metadata
* `Used` - The final version used based on the requirement constraint
* `Chef Latest` - The latest version available on the Chef server
* `Repository Latest` - The latest version available on the Repository Manager
* `Requirement Status` - The status of the cookbook:
    * up-to-date (a green tick mark): the right version is picked
    * warning-req (a yellow esclamation point): a newer version could be used
    * error (a red x mark): no versions could be found
* `Chef Server Status` - The status of the chef server:
    * up-to-date (a green tick mark): the server is up to date
    * warning-chef (a blue 'i'): on the Repository Manager there's a newer version
    * error (a red x mark): no versions could be found
* `Repository Status` - The status of the Repository Manager:
    * up-to-date (a green tick mark): the server is up to date
    * warning-repomanager (two yellow esclamation points): on Chef there's a newer version
    * error (a red x mark): no versions could be found
* `Remarks` - human readable descriptions of warnings/errors

The overall status will also be displayed in the bottom of the table.

### Display Format

Two display formats are supported: table and json

1. The table format will display the dependency status as an ASCII table
2. The json format will display the dependency status as a JSON object

### Examples

    +------------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name       | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository |
    |            |             |       | Latest | Latest     | Status      | Status      | Status     |
    +------------+-------------+-------+--------+------------+-------------+-------------+------------+
    | apache2    | = 1.8.2     | 1.8.2 | 1.8.2  | 1.8.4      |      ✔      |      i      |   ✔        |
    | mysql      | = 1.1.2     | 1.1.2 | 1.1.3  | 1.1.4      |      !      |      i      |   ✔        |
    | database   | = 1.5.3     | 1.5.3 | 1.5.3  | 1.5.2      |      ✔      |      ✔      |   !!       |
    | postgresql | = 3.1.0     |       | 3.0.5  | 3.1.0      |      ✖      |      i      |   ✔        |
    | activemq   | = 1.1.0     | 1.1.0 | 1.1.1  | 1.1.1      |      !      |      ✔      |   ✔        |
    | yum        | = 2.3.4     | 2.3.4 | 2.3.4  | 2.3.4      |      ✔      |      ✔      |   ✔        |
    | ssh-keys   | = 1.0.0     | 1.0.0 | 1.0.0  |            |      ✔      |      ✔      |   ✖        |
    | selinux    | = 0.5.6     | 0.5.6 | 0.5.6  | 0.5.6      |      ✔      |      ✔      |   ✔        |
    |  › keytool | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      ✔      |      ✔      |   ✔        |
    +------------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: err (✖)

**Note:** The option *--remarks* provides more verbose descriptions for errors/warnings

    $ kitchen-inspector  --remarks
    +------------------+-------------+--------+--------+------------+-------------+-------------+------------+---------+
    | Name             | Requirement | Used   | Chef   | Repository | Requirement | Chef Server | Repository | Remarks |
    |                  |             |        | Latest | Latest     | Status      | Status      | Status     |         |
    +------------------+-------------+--------+--------+------------+-------------+-------------+------------+---------+
    | apache2          | = 1.8.2     | 1.8.2  | 1.8.2  | 1.8.2      |      ✔      |      ✔      |     !      | 1       |
    | mysql            | = 1.1.3     | 1.1.3  | 1.1.3  | 1.1.4      |      ✔      |      i      |     ✔      | 2       |
    | postgresql       | = 3.0.5     | 3.0.5  | 3.0.5  | 3.0.5      |      ✔      |      ✔      |     !      | 3       |
    | build-essential  | ~> 1.4.2    | 1.4.2  | 1.4.2  | 1.4.2      |      ✔      |      ✔      |     ✔      |         |
    | database         | >= 0.0.0    | 1.5.3  | 1.5.3  | 1.5.2      |      ✔      |      ✔      |     !!     | 4       |
    +------------------+-------------+--------+--------+------------+-------------+-------------+------------+---------+
    Status: warn-outofdate-repo (!!)

    Remarks:
    [1]: GitLab's last tag is 1.8.4 but found 1.8.2 in metadata.rb
    [2]: A new version might appear on Chef server
    [3]: GitLab's last tag is 3.1.0 but found 3.0.5 in metadata.rb
    [4]: GitLab out-of-date!

### Recursive dependencies

In order to turn off recursive analysis, simply use _--recursive false_.

## Configuration

By default *${HOME}/.chef/kitchen_inspector.rb* is picked, but _--config_ can be used to override that setting.

Valid Repository Manager and Chef Server configurations must be provided.  
When a Chef Server configuration is not specified in *kitchen_inspector.rb* it fallbacks to *${HOME}/.chef/knife.rb*, if present.

```
$ kitchen-inspector --config config_example.rb
```

### Chef server

Example:

```ruby
# Chef Server configuration
chef_server :url => "https://chefsrv.example.org",
            :username => "chef_usename",
            :client_pem => "/path/to/chef_client_pem"
```

### GitLab

GitLab access can be configured specifying a *token* and a *base_url*.

Example:

```ruby
# Repository Manager configuration
repository_manager :type => "GitLab",
                   :base_url => "http://gitlab.example.org",
                   :token => "gitlab_token" # (GitLab > Profile > Account)
```

### GitHub

GitHub access can be configured specifying a *token* and a list of *allowed users* that
host the cookbooks you're interested in.

*PLEASE NOTE* that GitHub has a strict [rate limit](http://developer.github.com/v3/#rate-limiting) on the calls you can make.
So, even though a *token* is not strictly required, it's better to configure it as well.  
From [GitHub's Applications page](https://github.com/settings/applications) go to "Personal Access Tokens" and generate a new token.

Due to the huge search space, searches against GitHub are restricted to profiles owned by *allowed_users* (aka GitHub usernames).
Cookbooks are thus searched only within those users' repositories, comparing cookbooks' names with repositories' names (Pattern "one repo per cookbook").

Example:

```ruby
# Repository Manager configuration
repository_manager :type => "GitHub",
                   :token => "github_token",
                   :allowed_users => ["opscode-cookbooks"]
```

## CI/CD Integration

Kitchen Inspector can be used in a Continuous Integration/Continuous Building/etc process, in order to validate cookbooks.

These are the available exit codes (see *common.rb*):

* 0 (:up_to_date): everything is OK!
* Errors
    * 100 (:err_req): a valid version could not be found
    * 101 (:err_repo): an error related to the Repository Manager
    * 102 (:err_config): configuration error
    * 103 (:err_notacookbok): the specified directory is not a Cookbook
* Warnings
    * 200 (:warn_req): a newer version could be used
    * 201 (:warn_mismatch_repo): metadata.rb's version and tag doesn't match
    * 202 (:warn_outofdate_repo): a newer version exists on Chef Server
    * 203 (:warn_chef): a newer version exists on Repository Manager

## Checks

In this section are listed the checks applied.

#### Everything is up to date

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository |
    |      |             |       | Latest | Latest     | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      ✔      |      ✔      |     ✔      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: up-to-date (✔)

#### Repository Manager doesn't contain any versions

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository |
    |      |             |       | Latest | Latest     | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.1 | 1.0.1  |            |      ✔      |      ✔      |     ✖      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: err-repo (✖)

#### Repository Manager contains a mismatched tag/metadata's version

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository |
    |      |             |       | Latest | Latest     | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      ✔      |      ✔      |     !      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: warn-mismatch-repo (!)

#### Repository Manager doesn't contain the last version

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository |
    |      |             |       | Latest | Latest     | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      ✔      |      ✔      |     !!     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: warn-outofdate-repo (!!)

#### Chef Server doesn't contain the last version

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository |
    |      |             |       | Latest | Latest     | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.0 | 1.0.0  | 1.0.1      |      ✔      |      i      |     ✔      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: warn-chef (i)

#### Metadata doesn't use the last version

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository |
    |      |             |       | Latest | Latest     | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | = 1.0.0     | 1.0.0 | 1.0.1  | 1.0.1      |      !      |      ✔      |     ✔      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: warn-req (!)

#### Metadata refers to a version not existing on Chef Server
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used | Chef   | Repository | Requirement | Chef Server | Repository |
    |      |             |      | Latest | Latest     | Status      | Status      | Status     |
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      ✖      |      ✔      |     ✔      |
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    Status: err (✖)

#### Chef Server doesn't contain any versions

    +------+-------------+------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used | Chef   | Repository | Requirement | Chef Server | Repository |
    |      |             |      | Latest | Latest     | Status      | Status      | Status     |
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    |      |        | 1.0.1      |      ✖      |      ✖      |     ✔      |
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    Status: err (✖)

#### Repository Manager contains two or more projects with the same name

**Note:** In this situation is not possible to decide which version generated the one on the Chef Server.

    +----------+-------------+-------+--------+------------+-------------+-------------+------------+---------+
    | Name     | Requirement | Used  | Chef   | Repository | Requirement | Chef Server | Repository | Remarks |
    |          |             |       | Latest | Latest     | Status      | Status      | Status     |         |
    +----------+-------------+-------+--------+------------+-------------+-------------+------------+---------+
    | database | >= 0.0.0    | 1.5.2 | 1.5.2  | 1.5.2      |      ✔      |      ✔      |     ?      | 1       |
    | database | >= 0.0.0    | 1.5.2 | 1.5.2  | 1.1.0      |      ✔      |      ✔      |     ?      | 2       |
    +----------+-------------+-------+--------+------------+-------------+-------------+------------+---------+
    Status: warn-notunique-repo (?)

    Remarks:
    [1]: Not unique on GitHub (this is github.com/opscode-cookbooks/database)
    [2]: Not unique on GitHub (this is github.com/cookbooks/database)

## Testing

Kitchen Inspector is tested using RSpec.
You can run tests using:

```bash
$ rake test
```

## LICENSE

Author:: Stefano Tortarolo (stefano.tortarolo@gmail.com)

Copyright:: Copyright (c) 2013-2014
License:: MIT License

## CREDITS
This code was heavily inspired by Kannan Manickam's [chef-taste](https://github.com/arangamani/chef-taste)

Special thanks to [Marco Boschetti](https://github.com/mbizkit76) for the huge amount of suggestions given.
