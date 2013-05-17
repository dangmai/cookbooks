Description
===========

This Chef (>= 11.2) cookbook is used to provision a [LAMP
stack](http://en.wikipedia.org/wiki/LAMP_(software_bundle)) on Ubuntu 12.04 or
newer releases (tested on Ubuntu 12.04, 12.10 and 13.04). It uses PHP-FPM and APC to create a faster and more secure PHP
environment.

This cookbook is fairly opinionated about how the system is set up, but still
allows for customizations. It uses items from a data bag (encrypted data bag is
supported) to set up new users/virtual hosts/FTP access/MySQL databases. Without
customization, users *only* have FTP access to their chrooted home folder (no
SSH is granted). This is akin to setting up a shared hosting account.

Cookbooks
=========

This cookbook relies on a number of community cookbooks:

- [apt](http://community.opscode.com/cookbooks/apt)
- [apache2](http://community.opscode.com/cookbooks/apache2)
- [database](http://community.opscode.com/cookbooks/database)
- [dotdeb](https://github.com/homemade/chef-dotdeb)
- [jolicode-php](https://github.com/jolicode/chef-cookbook-php)
- [mysql](http://community.opscode.com/cookbooks/mysql)
- [vsftpd](https://github.com/dangmai/chef-vsftpd/tree/backport)

Attributes
==========

- node[:lamp][:databag] - Name of the data bag that holds the configuration.
  Default is "accounts".
- node[:lamp][:encrypted] - Whether the data bag is encrypted or not. Default is
  true (it is also recommended that you use encrypted data bags, for it may
  contain passwords).
- node[:lamp][:www\_dir] - The name of the directory in which virtual hosts
  reside. Default is "public_html".

This cookbook also mostly honor the attributes for the cookbooks that it depends
on (Apache, MySQL, et al), so you can override those cookbooks' attributes to
change the behavior for this cookbook.

Usage
=====

The most basic data bag item possible for this cookbook is:

```
{
  "id": "another_user"
}
```

which creates a user with FTP access to his/her home directory
(`/home/another_user`), but without associated password, virtual hosts or
databases.

A more interesting data bag item is:

```
{
  "id": "test_account",
  "comment": "User to run PHP apps",
  "username": "php_user",
  "uid": 1010,
  "password": "php_user_password"
  "virtual_hosts": [
    {
      "server_name": "example.com",
      "server_aliases": [
        "www.example.com",
        "blog.example.com"
      ],
      "php_fpm": {
        "max_children": 10
      }
    },
    {
      "server_name": "example1.com",
      "server_aliases": [
        "www.example1.com",
        "news.example1.com"
      ]
    }
  ],
  "databases": [
    {
      "name": "exampledb"
    },
    {
      "name": "exampledb2",
      "user": "example-user",
      "password": "password_that_wont_be_used"
    },
    {
      "name": "exampledb3",
      "user": "example-user",
      "password": "password_that_will_be_used"
    }
  ]
}
```

Based on this data bag item, the cookbook will generate a user with 2 virtual
hosts, 3 databases and FTP access to his/her home directory. A few interesting
notes about this data bag item:

- Outside of `virtual_hosts` and `databases`, all other attributes are taken
  straight out of the [user](http://docs.opscode.com/resource_user.html)
  resource, and you can change them to your liking (please look at the user
  resource page for possible changes). The one difference is that the password
  should be plain-text in the data bag item (which is why it is recommended that
  the data bag is encrypted). *Note:* Be careful if you set the user shell to anything other than `/bin/false` - by default, the user's FTP access is chrooted to his/her home directory, which can be overcome if the user is granted SSH access.

- `virtual_hosts` consist of entries that correspond to the
  [web_app](https://github.com/opscode-cookbooks/apache2#web_app) definition in
  Apache2 cookbook. All of `web_app` parameters are supported. For each
  `virtual_host`, a PHP-FPM pool will automatically be created so that the user
  can use PHP web applications in a more flexible and secured manner.

- `php_fpm` is a special hash inside a `virtual_host` entry that specify the
  parameters for the PHP-FPM server. It corresponds to the
  [jolicode\_php\_fpm_pool](https://github.com/jolicode/chef-cookbook-php#php-
  fpm) resource and accepts all attributes for that resource.

- `databases` consist of databases that should be created for this account. It
  supports 3 attributes: `name` (required), `user` (optional) and `password`
  (optional). If `user` or `password` is omitted, the username and password
  specified for this account will be used in their places. *Note*: if multiple
  database entries have the same user but different passwords, the last password
  will be used for that user.

Special Notes
=============

In order to set up FTP access for the user, this cookbook automatically installs
VSFTPD 3 instead of VSFTPD 2 (the default version in earlier versions of
Ubuntu), because the newer version allows the chrooted user to write to his/her
home directory. Unfortunately, there is no backported version of VSFTPD 3 for
older Ubuntu releases yet; therefore, this cookbook will pin the Raring Ringtail's version of VSFTPD 3 for Ubuntu 12.04 and 12.10.