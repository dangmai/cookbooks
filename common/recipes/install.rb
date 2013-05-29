#
# Cookbook Name:: common
# Recipe:: install
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

platform = node[:platform]
# Tiny exception of OS X server here
family = platform?("mac_os_x_server") ? "mac_os_x" : node[:platform_family]
# I use Homebrew for OS X, so here I need to figure out which users to install
# Homebrew programs in.
users = data_bag(node[:common][:users_data_bag])
homebrew_users = []
users.each do |entry|
  if node[:common][:encrypted_users_data_bag]
    user = Chef::EncryptedDataBagItem.load(node[:common][:users_data_bag], entry)
  else
    user = data_bag_item(node[:common][:users_data_bag], entry)
  end
  if user["homebrew"]
    homebrew_users.push(user["username"])
  end
end

# Install and update package managers' cache if necessary
case family
when "debian"
  include_recipe "apt"
when "arch"
  include_recipe "pacman"
when "windows"
  include_recipe "chocolatey"
when "mac_os_x" || "mac_os_x_server"
  include_recipe "homebrew"
end

# Install packages
attribute = node[:common][:packages_data_bag_item].split("/")
bag_item = data_bag_item(attribute[0], attribute[1])

to_install = []
packages = bag_item["packages"]
# Figure out which packages are needed
# Steps: common -> common_except_windows -> family -> platform -> negation
to_install = to_install.concat(packages["common"]) if packages["common"]
unless platform == "windows"
  to_install = to_install.concat(packages["common_except_windows"]) if packages["common_except_windows"]
end
to_install = to_install.concat(packages["family_#{family}"]) if packages["family_#{family}"]
to_install = to_install.concat(packages[platform]) if packages[platform]
to_install.each_with_index do |item, index|
  if item.start_with?("-")
    r = item[1, item.length() - 1]
    remove_index = to_install.index(r)
    if remove_index
      to_install[remove_index] = nil
      to_install[index] = nil
    end
  end
end

# Homebrew workaround for multiple users
if family == "mac_os_x" && homebrew_users.size() > 0
  group "brew" do
    append :true
    members homebrew_users
  end
  directory "/usr/local" do
    owner homebrew_users[0]
    group "brew"
    mode "775"  # allows for group write
  end
  node.override["homebrew"]["run_as"] = homebrew_users[0]
end

to_install.each do |item|
  if platform == "windows"
    chocolatey item if item
  elsif (family == "mac_os_x" && homebrew_users.size() > 0) || (family != "mac_os_x")
    package item if item
  end
end

# Special packages
if packages["python"]
  include_recipe "python"
  packages["python"].each do |python_package|
    python_pip python_package
  end
end

if packages["ruby"]
  # Install rvm and the ruby packages as global gems in the default rvm
  gems_to_install = []
  packages["ruby"].each do |ruby_package|
    gems_to_install.push({ "name" => ruby_package })
  end
  node.override['rvm']['global_gems'] = gems_to_install
  include_recipe "rvm::system"
end

if packages["nodejs"]
  node.override[:nodejs][:'install_method'] = 'package'
  include_recipe "nodejs"
  packages["nodejs"].each do |node_package|
    npm_package node_package
  end
end