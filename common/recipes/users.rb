#
# Cookbook Name:: common
# Recipe:: users
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

include_recipe "git"

# Install unix-crypt to encrypt UNIX password
chef_gem "unix-crypt"
require 'unix_crypt'

users = data_bag(node[:common][:users_data_bag])
users.each do |entry|
  if node[:common][:encrypted_users_data_bag]
    user = Chef::EncryptedDataBagItem.load(node[:common][:users_data_bag], entry)
  else
    user = data_bag_item(node[:common][:users_data_bag], entry)
  end

  username = user["username"]
  password = user["password"] ? UnixCrypt::SHA256.build(user["password"]) : nil
  if platform?("windows")
    home_dir = nil
  elsif platform?("mac_os_x") || platform?("mac_os_x_server")
    home_dir = "/Users/#{username}"
  else
    home_dir = "/home/#{username}"
  end

  user username do
    home home_dir
    # Currently password hashing is broken on OS X
    # Assumption is that we run this as our desired user on OS X anyway, so
    # this shouldn't be a big deal
    password password unless platform?("mac_os_x_server") || platform?("mac_os_x")
    supports :manage_home => true
  end

  # Add user to sudoers
  sudo_group = "sudo"
  if platform?("mac_os_x") || platform?("mac_os_x_server")
    sudo_group = "admin"
  end
  group sudo_group do
    members [username]
    append true
    action :modify
  end

  user_group = platform?("mac_os_x") || platform?("mac_os_x_server") ? "staff" : username
  # Generate authorized keys for user
  if user["ssh_keys"]
    directory "#{home_dir}/.ssh" do
      owner username
      group user_group
      mode "0700"
    end

    template "#{home_dir}/.ssh/authorized_keys" do
      source "authorized_keys.erb"
      owner username
      group user_group
      mode "0600"
      variables :ssh_keys => user['ssh_keys']
    end
  end

  # Execute commands
  user["execute"].each do |e|
    path = "#{home_dir}/#{e["path"]}"

    directory path do
      user username
      group user_group
      recursive true
      action :create
    end

    git path do
      repository e["location"]
      reference e["reference"] || "master"
      user username
      group user_group
      action :sync
     end

    if e["commands"]
      e["commands"].each do |cmd|
        execute "su -l -c 'HOME=#{home_dir} && cd #{path} && #{cmd}' '#{username}'"
      end
    end
  end
end
