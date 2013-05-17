#
# Cookbook Name:: personal-website
# Recipe:: default
#
# Copyright (C) 2013 Dang Mai
# 
# All rights reserved - Do Not Redistribute
#

# Change the default nodejs installation to 'package' instead of 'source'. You
# can also change the nodejs and npm version, by overriding the :version and
# :npm attributes on the nodejs cookbook.
node.override[:nodejs][:'install_method'] = 'package'

include_recipe "apt"
include_recipe "apache2"
include_recipe "git"
include_recipe "nodejs"

parent_dir = node[:"personal-website"][:dir]
checkout_dir = "#{parent_dir}/website"
user = node[:"personal-website"][:user]
group = node[:"personal-website"][:group]

apache_module "rewrite" do
  enable true
end

# Create the parent dir if it doesn't exist
directory checkout_dir do
  owner user
  group group
  mode 00744
  action :create
  recursive true
end

# Clone the repository from Github page
git checkout_dir do
  repository node[:"personal-website"][:git]
  action :sync
  user user
  group group
end

npm_package "bower@" + node[:"personal-website"][:bower]

# Bower uses the home dir to store some files, but there's no guarantee that
# the user running this has permission to his/her home dir, so we use the OS'
# temp dir instead. Also, the command is run in a non-login shell (#CHEF-2288),
# so we have to su to a login shell for Bower to work correctly.
require 'tmpdir'
execute "su -l -c 'HOME=#{Dir.tmpdir()} && cd #{checkout_dir} && bower install' '#{user}'"

web_app "dangmai.net" do
  server_name "dangmai.net"
  server_aliases ["www.dangmai.net"]
  docroot checkout_dir
  template "dangmai.conf.erb"
end