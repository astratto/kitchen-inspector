# Kitchen Inspector

Kitchen Ispector is a CLI utility inspired by chef-taste to check a cookbook's dependency status against a Chef server and a Gitlab instance.

It assumes that your kitchen is composed by:

* a Chef server containing the cookbooks to be used
* a Gitlab instance hosting cookbook's development

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

A valid configuration must be provided in order to configure the Chef and Gitlab servers.  
By default *${HOME}/.chef/kitchen_inspector.rb* is picked, but _--config_ can be used to override that setting.

Example:

    gitlab_base_url "http://gitlab.example.org"
    gitlab_token "gitlab_token" # (Gitlab > Profile > Account)

    chef_server_url "https://chefsrv.example.org"
    chef_username "chef_usename"
    chef_client_pem "/path/to/chef_client_pem"

From inside the cookbook's directory, type `kitchen-inspector` to inspect your kitchen.
It's also possible to specify a target directory with `kitchen-inspector investigate PATH`.

The `metadata.rb` of the cookbook is parsed to obtain the dependencies, then the configured Chef server and Gitlab server are queried to define which versions are available.  
**Note:** The Chef server's version is the one that defines the used version.

It will display a table that contains the following rows:

* `Name` - The name of the cookbook
* `Requirement` - The version requirement specified in the metadata
* `Used` - The final version used based on the requirement constraint
* `Latest Chef` - The latest version available on the Chef server
* `Latest Gitlab` - The latest version available on the Gitlab server
* `Requirement Status` - The status of the cookbook:
    * up-to-date (a green tick mark): the right version is picked
    * warning-req (a yellow esclamation point): a newer version could be used
    * error (a red x mark): no versions could be found
* `Chef Server Status` - The status of the chef server:
    * up-to-date (a green tick mark): the server is up to date
    * warning-chef (a blue 'i'): on Gitlab there's a newer version
    * error (a red x mark): no versions could be found
* `Gitlab Status` - The status of the Gitlab server:
    * up-to-date (a green tick mark): the server is up to date
    * warning-gitlab (two yellow esclamation points): on Chef there's a newer version
    * error (a red x mark): no versions could be found
* `Remarks` - human readable descriptions of warnings/errors

The overall status will also be displayed in the bottom of the table.

### Display Format

Two display formats are supported: table and json

1. The table format will display the dependency status as an ASCII table
2. The json format will display the dependency status as a JSON object

### Examples

    +-----------+-------------+-------+--------+--------+-------------+-------------+--------+--------------------+
    | Name      | Requirement | Used  | Latest | Latest | Requirement | Chef Server | Gitlab | Remarks            |
    |           |             |       | Chef   | Gitlab | Status      | Status      | Status |                    |
    +-----------+-------------+-------+--------+--------+-------------+-------------+--------+--------------------+
    | apt       | = 2.3.4     | 2.3.4 | 2.3.4  | 2.3.8  |      ✔      |      !      |   ✔    | A new version might appear on Chef server|
    | jbosseap6 | ~> 0.9.3    | 0.9.8 | 0.10.0 | 0.10.0 |      ✔      |      ✔      |   ✔    |                    |
    | database  | = 1.5.2     | 1.5.2 | 1.5.3  | 1.5.2  |      !      |      ✔      |   !!   | 1.5.3 is available, Gitlab out-of-date! |
    | yum       | = 2.3.4     | 2.3.4 | 2.3.4  | 2.3.4  |      ✔      |      ✔      |   ✔    |                    |
    | git       | = 1.8.1     | 1.8.1 | 1.8.4  | 1.8.4  |      !      |      ✔      |   ✔    | 1.8.4 is available |
    | hadoop    | ~> 1.1.0    |       |        | 1.0.0  |      ✖      |      !      |   ✔    | No versions found  |
    | zookeeper | = 1.0.0     |       |        | 1.0.0  |      ✖      |      !      |   ✔    | No versions found  |
    +-----------+-------------+-------+--------+--------+-------------+-------------+--------+--------------------+
    Status: error (✖)

### Recursive dependencies

There's an option _--recursive boolean_ that turns off recursive analysis.


## LICENSE

Author:: Stefano Tortarolo <stefano.tortarolo@gmail.com>

Copyright:: Copyright (c) 2013
License:: MIT License

## CREDITS
This code was heavily inspired by Kannan Manickam's [chef-taste](https://github.com/arangamani/chef-taste)
