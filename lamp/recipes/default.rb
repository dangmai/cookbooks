#
# Cookbook Name:: lamp
# Recipe:: default
#
# Copyright (C) 2013 Dang Mai
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

include_recipe "apt"
if platform?("debian")
  # For Debian, dotdeb needs to be enabled for php-fpm to work correctly
  node.override[:'jolicode-php'][:dotdeb] = true
  include_recipe "dotdeb"
end

include_recipe "apache2"
# For Ubuntu, make sure that multiverse repo is turned on, or mod_fastcgi won't
# install
if platform?("ubuntu")
  version = node[:lsb][:codename]
  [version, "#{version}-updates"].each do |dist|
    apt_repository "#{dist}-multiverse" do
      uri "http://archive.ubuntu.com/ubuntu"
      distribution dist
      components ["multiverse"]
    end
  end
end
include_recipe "apache2::mod_fastcgi"
include_recipe "database::mysql"
include_recipe "jolicode-php"
include_recipe "jolicode-php::ext-fpm"
include_recipe "jolicode-php::ext-apc"
include_recipe "jolicode-php::ext-mysql"
include_recipe "mysql::server"
include_recipe "lamp::setup_ftp"

# Install unix-crypt to encrypt UNIX password
chef_gem "unix-crypt"
require 'unix_crypt'

# Configuring PHP-FPM with Apache requires actions module to be enabled
apache_module "actions" do
  enable true
end

accounts = data_bag(node[:lamp][:databag])
accounts.each do |entry|
  if node[:lamp][:encrypted]
    account = Chef::EncryptedDataBagItem.load(node[:lamp][:databag], entry)
  else
    account = data_bag_item(node[:lamp][:databag], entry)
  end
  uid = account["uid"]
  gid = account["gid"]
  shell = account["shell"] || "/bin/false"
  comment = account["comment"]
  username = account["username"] || account["id"]
  password = account["password"] ? UnixCrypt::SHA256.build(account["password"]) : nil
  home = account["home"] || "/home/#{username}"
  www_dir = "#{home}/#{node[:lamp][:www_dir]}"

  user(account["id"]) do
    uid       uid
    gid       gid
    shell     shell
    comment   comment
    username  username
    password  password
    home      home
    supports  :manage_home => true
  end

  directory www_dir do
    owner username
    group gid || username
    action :create
  end

  account['virtual_hosts'].each do |vh|
    Chef::Application.fatal!("server_name is required for a virtual host") unless vh["server_name"]
    host_dir = "#{www_dir}/#{vh["server_name"]}"
    application_name = vh["application_name"] || vh["server_name"]

    directory host_dir do
      owner username
      group gid || username
      action :create
    end
    # Set up php_fpm to listen on socket
    php_conf = vh["php_fpm"] || {}
    jolicode_php_fpm_pool application_name do
      user php_conf["username"] || username
      group php_conf["group"] ? php_conf["group"] : gid ? gid.to_s : username
      listen php_conf["listen"] if php_conf["listen"]
      max_children php_conf["max_children"] if php_conf.has_key?("max_children")
      process_manager php_conf["process_manager"] if php_conf.has_key?("process_manager")
      start_servers php_conf["start_servers"] if php_conf.has_key?("start_servers")
      min_spare_servers php_conf["min_spare_servers"] if php_conf.has_key?("min_spare_servers")
      max_spare_servers php_conf["max_spare_servers"] if php_conf.has_key?("max_spare_servers")
      max_requests php_conf["max_requests"] if php_conf.has_key?("max_requests")
      status_path php_conf["status_path"] if php_conf.has_key?("status_path")
      set_chdir php_conf["set_chdir"] if php_conf.has_key?("set_chdir")
      set_chroot php_conf["set_chroot"] if php_conf.has_key?("set_chroot")
      action :create
    end

    # Set up virtual host(s) for the account
    web_app(vh["server_name"]) do
      server_name vh["server_name"]
      server_aliases vh["server_aliases"] || []
      docroot host_dir
      template vh["template"] ? vh["template"] : "web_app.conf.erb"
      cookbook vh["cookbook"] ? vh["cookbook"] : nil
      application_name application_name
      allow_override vh["allow_override"]
      directory_options vh["directory_options"] || []
    end
  end

  mysql_connection_info = {
    :host => "localhost",
    :username => "root",
    :password => node[:mysql][:server_root_password]
  }
  account['databases'].each do |db|
    Chef::Application.fatal!("Parameter name is required for a database") unless db["name"]
    name = db["name"]
    user = db["user"] || username
    password = db["password"] || account["password"]
    Chef::Application.fatal!("A password is required for a MySQL database") unless password
    mysql_database name do
      connection mysql_connection_info
      action :create
    end
    # The last password will be honored for this user
    mysql_database_user user do
      connection mysql_connection_info
      password password
      action :create
    end
    # Granting permissions on the database to the user
    mysql_database_user user do
      connection mysql_connection_info
      database_name name
      action :grant
    end
  end
end

# Make sure PHP-FPM picks up the configuration files we create earlier
service "php5-fpm" do
  action :restart
end