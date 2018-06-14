#
# Cookbook:: couchbase
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.

yum_package 'pkgconfig'
yum_package 'openssl098e'

user = attribute String, 'couchbase', 'user'
group =  attribute String, 'couchbase', 'group'
couchbase_version =  attribute String, 'couchbase', 'version'
source_url =  attribute String, 'couchbase', 'source_url'


group group

user user do
  group group
end

directory '/srv/couchbase' do
  owner user
  group group
  mode '0755'
end

directory '/opt/couchbase' do
  owner user
  group group
  mode '0755'
end

mount '/opt/couchbase' do
  device '/srv/couchbase'
  options 'bind'
  action :mount
  not_if "[[ $(ls -id /srv/couchbase/ | awk '{print $1}') == $(ls -id /opt/couchbase/ | awk '{print $1}') ]]"
end

directory '/etc/tuned/no_thp_profile/' do
  owner 'root'
  group 'root'
  mode '0644'
end

cookbook_file '/etc/tuned/no_thp_profile/tuned.conf' do
  source 'tuned.conf'
  mode '0774'
  owner 'root'
  group 'root'
end

execute 'disable-transparent-huge-pagest' do
  command "tuned-adm profile no_thp_profile"
  not_if { File.read('/sys/kernel/mm/transparent_hugepage/enabled') == "always madvise [never]\n" }
end


download = remote_file "srv/couchbase/couchbase.rpm" do 
  source "ftp://10.10.10.10/mirror/couchbase-server-community-#{couchbase_verison}-centos6.x86_64.rpm"
  ftp_active_mode node['couchbase']['ftp_active_mode']
  not_if "rpm -qa | grep -q 'couchbase'"
end

 
rpm_package 'couchbase' do
  source '/srv/couchbase/couchbase.rpm'
  not_if "rpm -qa | grep -q 'couchbase'"
end

file '/srv/couchbase/couchbase.rpm' do 
  action :delete
end 
