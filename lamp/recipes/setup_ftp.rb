#
# Cookbook Name:: lamp
# Recipe:: setup_ftp
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
include_recipe "vsftpd"

version = node["platform_version"]
if platform?("ubuntu") && version == "12.04" || version == "12.10"
  # Pin vsftpd 3 from Raring, because it allows for writing to chrooted home dir
  file "/etc/apt/apt.conf.d/99lamp" do
    content "APT::Default-Release \"#{node["lsb"]["codename"]}\";"
    mode "644"
  end

  apt_repository "raring" do
    uri "http://archive.ubuntu.com/ubuntu"
    distribution "raring"
    components ["main"]
  end

  apt_preference "vsftpd" do
    pin "version 3*"
    pin_priority "1001"
  end
end

# Change PAM config for vsftpd, so that users with non-login shell can get FTP
# access
ruby_block "make sure vsftpd allows local users with non-login shells" do
  block do
    fe = Chef::Util::FileEdit.new("/etc/pam.d/vsftpd")
    fe.search_file_delete_line(/pam_shells.so/)
    fe.write_file
  end
end