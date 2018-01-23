# # encoding: utf-8

# Inspec test for recipe couchbase::default

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

describe command('yum list installed | grep pkgconfig') do
  its('stdout') { should include "pkgconfig" }
end

describe command('yum list installed | grep openssl098e') do
  its('stdout') { should include "openssl098e" }
end

describe directory('/etc/tuned/no_thp_profile/') do
  it { should exist }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'root' }
  its('mode') { should cmp '0644' }
end

describe file('/etc/tuned/no_thp_profile/tuned.conf') do
  it { should exist }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'root' }
  its('mode') { should cmp '0774' }
  its('content') {should include 'transparent_hugepages=never'}
end

describe file('/sys/kernel/mm/transparent_hugepage/enabled') do
  it { should exist }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'root' }
  its('content') {should include 'always madvise [never]'}
end

describe directory('/srv/couchbase') do
  it { should exist }
  it { should be_owned_by 'couchbase' }
  it { should be_grouped_into 'couchbase' }
  its('mode') { should cmp '0774' }
end

describe file('/srv/couchbase/couchbase.rpm') do
  it { should_not exist }
end

describe file('/opt/couchbase/bin/couchbase-cli') do
  it { should exist }
  it { should be_owned_by 'bin' }
  it { should be_grouped_into 'bin' }
  it { should be_executable }
end