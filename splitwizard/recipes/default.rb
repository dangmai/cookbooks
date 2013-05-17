#
# Cookbook Name:: splitwizard
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

# Change the default nodejs installation to 'package' instead of 'source'. You
# can also change the nodejs and npm version, by overriding the :version and
# :npm attributes on the nodejs cookbook.
node.override[:nodejs][:'install_method'] = 'package'

include_recipe "apt"
include_recipe "apache2"
include_recipe "git"
include_recipe "nodejs"

parent_dir = node[:splitwizard][:dir]
checkout_dir = "#{parent_dir}/splitwizard"
user = node[:splitwizard][:user]
group = node[:splitwizard][:group]

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
  repository node[:splitwizard][:git]
  action :sync
  user user
  group group
end

npm_package "volo@" + node[:splitwizard][:volo]

# Bower uses the home dir to store some files, but there's no guarantee that
# the user running this has permission to his/her home dir, so we use the OS'
# temp dir instead. Also, the command is run in a non-login shell (#CHEF-2288),
# so we have to su to a login shell for Bower to work correctly.
require 'tmpdir'
execute "su -l -c 'HOME=#{Dir.tmpdir()} && cd #{checkout_dir} && npm install "\
        "&& volo build /' '#{user}'"

web_app "splitwizard.com" do
  server_name "splitwizard.com"
  server_aliases ["www.splitwizard.com"]
  docroot "#{checkout_dir}/www-built"
  template "splitwizard.conf.erb"
end