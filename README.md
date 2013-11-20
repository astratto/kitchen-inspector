# Kitchen Inspector
[![Build Status](https://travis-ci.org/astratto/kitchen-inspector.png?branch=master)](https://travis-ci.org/astratto/kitchen-inspector)

Kitchen Ispector is a CLI utility inspired by chef-taste to check a cookbook's dependency status against a Chef server and a Repository Manager instance.

It assumes that your kitchen is composed by:

* a Chef server containing the cookbooks to be used
* a Repository Manager instance hosting cookbook's development
    * at this stage only Gitlab is supported

This tool checks whether the dependencies specified are up to date or not.
It also shows whether one of the servers must be aligned.

By default, dependencies are recursively analyzed.

## Installation

Add this line to your application's Gemfile:

    gem 'kitchen-inspector'

And then execute:

    $ bundle

Or install it with:

    $ gem install kitchen-inspector

## Usage

A valid configuration must be provided in order to configure the Chef Server and the Repository Manager.  
By default *${HOME}/.chef/kitchen_inspector.rb* is picked, but _--config_ can be used to override that setting.

Example:

    repository_manager :type => "Gitlab",
                       :base_url => "http://gitlab.example.org",
                       :token => "gitlab_token" # (Gitlab > Profile > Account)

    chef_server_url "https://chefsrv.example.org"
    chef_username "chef_usename"
    chef_client_pem "/path/to/chef_client_pem"

From inside the cookbook's directory, type `kitchen-inspector` to inspect your kitchen.
It's also possible to specify a target directory with `kitchen-inspector investigate PATH`.

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
    | activemq   | = 1.1.0     | 1.1.0 | 1.1.1  | 1.1.1      |      !      |      ✔      |   ✔        |
    | postgresql | = 3.1.0     |       | 3.0.5  | 3.1.0      |      ✖      |      i      |   ✔        |
    | yum        | = 2.3.4     | 2.3.4 | 2.3.4  | 2.3.4      |      ✔      |      ✔      |   ✔        |
    | ssh-keys   | = 1.0.0     | 1.0.0 | 1.0.0  |            |      ✔      |      ✔      |   ✖        |
    | selinux    | = 0.5.6     | 0.5.6 | 0.5.6  | 0.5.6      |      ✔      |      ✔      |   ✔        |
    | keytool    | ~> 1.0.0    | 1.0.1 | 1.0.1  | 1.0.1      |      ✔      |      ✔      |   ✔        |
    +------------+-------------+-------+--------+------------+-------------+-------------+------------+
    Status: error (✖)

**Note:** The option *--remarks* provides more verbose descriptions for errors/warnings

### Recursive dependencies

There's an option _--recursive boolean_ that turns off recursive analysis.


## LICENSE

Author:: Stefano Tortarolo <stefano.tortarolo@gmail.com>

Copyright:: Copyright (c) 2013
License:: MIT License

## CREDITS
This code was heavily inspired by Kannan Manickam's [chef-taste](https://github.com/arangamani/chef-taste)
