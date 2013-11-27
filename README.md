# Kitchen Inspector
[![Build Status](https://travis-ci.org/astratto/kitchen-inspector.png?branch=master)](https://travis-ci.org/astratto/kitchen-inspector)
[![Dependency Status](https://gemnasium.com/astratto/kitchen-inspector.png)](https://gemnasium.com/astratto/kitchen-inspector)
[![Gem Version](https://badge.fury.io/rb/kitchen-inspector.png)](http://badge.fury.io/rb/kitchen-inspector)
[![Code Climate](https://codeclimate.com/github/astratto/kitchen-inspector.png)](https://codeclimate.com/github/astratto/kitchen-inspector)
[![Coverage Status](https://coveralls.io/repos/astratto/kitchen-inspector/badge.png)](https://coveralls.io/r/astratto/kitchen-inspector)

Kitchen Ispector is a CLI utility to check a cookbook's dependency status against a Chef server and a Repository Manager instance.

In particular, this tool checks whether the dependencies specified in a cookbook's metadata are up to date or not.
It also shows whether one of the servers must be aligned.

By default, dependencies are recursively analyzed and transitive dependencies are shown indented.

It assumes that your kitchen is composed by:

* a Chef server containing the cookbooks to be used
* a Repository Manager instance hosting cookbook's development

**Note:** at this stage only Gitlab is supported.

## Checks

In this section are listed the checks applied.

### Everything is up to date

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Latest | Latest     | Requirement | Chef Server | Repository |
    |      |             |       | Chef   | Repository | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      ✔      |      ✔      |     ✔      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: up-to-date (✔)

### Repository Manager doesn't contain any versions

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Latest | Latest     | Requirement | Chef Server | Repository |
    |      |             |       | Chef   | Repository | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.1 | 1.0.1  |            |      ✔      |      ✔      |     ✖      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: error-repomanager (✖)

### Repository Manager contains a mismatched tag/metadata's version

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Latest | Latest     | Requirement | Chef Server | Repository |
    |      |             |       | Chef   | Repository | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      ✔      |      ✔      |     !      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: warning-mismatch-repomanager (!)

### Repository Manager doesn't contain the last version

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Latest | Latest     | Requirement | Chef Server | Repository |
    |      |             |       | Chef   | Repository | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.0      |      ✔      |      ✔      |     !!     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: warning-outofdate-repomanager (!!)

### Chef Server doesn't contain the last version

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Latest | Latest     | Requirement | Chef Server | Repository |
    |      |             |       | Chef   | Repository | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    | 1.0.0 | 1.0.0  | 1.0.1      |      ✔      |      i      |     ✔      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: warning-chef (i)

### Metadata doesn't use the last version

    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used  | Latest | Latest     | Requirement | Chef Server | Repository |
    |      |             |       | Chef   | Repository | Status      | Status      | Status     |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    | Test | = 1.0.0     | 1.0.0 | 1.0.1  | 1.0.1      |      !      |      ✔      |     ✔      |
    +------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: warning-req (!)

### Metadata refers to a version not existing on Chef Server
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used | Latest | Latest     | Requirement | Chef Server | Repository |
    |      |             |      | Chef   | Repository | Status      | Status      | Status     |
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    |      | 1.1.0  | 1.1.0      |      ✖      |      ✔      |     ✔      |
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    Status: error (✖)

### Chef Server doesn't contain any versions

    +------+-------------+------+--------+------------+-------------+-------------+------------+
    | Name | Requirement | Used | Latest | Latest     | Requirement | Chef Server | Repository |
    |      |             |      | Chef   | Repository | Status      | Status      | Status     |
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    | Test | ~> 1.0.0    |      |        | 1.0.1      |      ✖      |      ✖      |     ✔      |
    +------+-------------+------+--------+------------+-------------+-------------+------------+
    Status: error (✖)

## Installation

Install it with:

```bash
$ gem install kitchen-inspector
```

## Usage

A valid configuration must be provided in order to configure the Chef Server and the Repository Manager.  
By default *${HOME}/.chef/kitchen_inspector.rb* is picked, but _--config_ can be used to override that setting.

Example:

```ruby
# Repository Manager configuration
repository_manager :type => "Gitlab",
                   :base_url => "http://gitlab.example.org",
                   :token => "gitlab_token" # (Gitlab > Profile > Account)

# Chef Server configuration
chef_server_url "https://chefsrv.example.org"
chef_username "chef_usename"
chef_client_pem "/path/to/chef_client_pem"
```

From inside the cookbook's directory, type `kitchen-inspector` to inspect your kitchen.
It's also possible to specify a target directory with `kitchen-inspector inspect PATH`.

The `metadata.rb` of the cookbook is parsed to obtain the dependencies, then the configured Chef server and Repository Manager are queried to define which versions are available.  
**Note:** The Chef server's version is the one that defines the used version.

It will display a table that contains the following rows:

* `Name` - The name of the cookbook
* `Requirement` - The version requirement specified in the metadata
* `Used` - The final version used based on the requirement constraint
* `Latest Chef` - The latest version available on the Chef server
* `Latest Repository` - The latest version available on the Repository Manager
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
    | Name       | Requirement | Used  | Latest | Latest     | Requirement | Chef Server | Repository |
    |            |             |       | Chef   | Repository | Status      | Status      | Status     |
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
    Status: error (✖)

**Note:** The option *--remarks* provides more verbose descriptions for errors/warnings

    $ kitchen-inspector  --remarks
    +------------------+-------------+--------+--------+------------+-------------+-------------+------------+---------+
    | Name             | Requirement | Used   | Latest | Latest     | Requirement | Chef Server | Repository | Remarks |
    |                  |             |        | Chef   | Repository | Status      | Status      | Status     |         |
    +------------------+-------------+--------+--------+------------+-------------+-------------+------------+---------+
    | apache2          | = 1.8.2     | 1.8.2  | 1.8.2  | 1.8.2      |      ✔      |      ✔      |     !      | 1       |
    | mysql            | = 1.1.3     | 1.1.3  | 1.1.3  | 1.1.4      |      ✔      |      i      |     ✔      | 2       |
    | postgresql       | = 3.0.5     | 3.0.5  | 3.0.5  | 3.0.5      |      ✔      |      ✔      |     !      | 3       |
    | build-essential  | ~> 1.4.2    | 1.4.2  | 1.4.2  | 1.4.2      |      ✔      |      ✔      |     ✔      |         |
    | database         | >= 0.0.0    | 1.5.3  | 1.5.3  | 1.5.2      |      ✔      |      ✔      |     !!     | 4       |
    +------------------+-------------+--------+--------+------------+-------------+-------------+------------+---------+
    Status: warning-outofdate-repomanager (!!)

    Remarks:
    [1]: Gitlab's last tag is 1.8.4 but found 1.8.2 in metadata.rb
    [2]: A new version might appear on Chef server
    [3]: Gitlab's last tag is 3.1.0 but found 3.0.5 in metadata.rb
    [4]: Gitlab out-of-date!

### Recursive dependencies

There's also an option _--recursive boolean_ that turns off recursive analysis.


## LICENSE

Author:: Stefano Tortarolo <stefano.tortarolo@gmail.com>

Copyright:: Copyright (c) 2013
License:: MIT License

## CREDITS
This code was heavily inspired by Kannan Manickam's [chef-taste](https://github.com/arangamani/chef-taste)
