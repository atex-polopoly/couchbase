default['couchbase']['cluster_name'] = 'dev'
default['couchbase']['cluster_admin'] = 'cmuser'
default['couchbase']['cluster_password'] = 'cmpasswd'
default['couchbase']['bucket_name'] = 'cmbucket'
default['couchbase']['bucket_password'] = 'cmpasswd'
default['couchbase']['data_path'] = '/data'
default['couchbase']['index_path'] = '/index'
default['couchbase']['host_name'] = '127.0.0.1'
default['couchbase']['user'] = 'couchbase'
default['couchbase']['group'] = 'couchbase'
default['couchbase']['ram_size'] = '500'
default['couchbase']['port'] = '8091'
default['couchbase']['index_ram_size'] = '500'
default['couchbase']['replicas'] = '1'
default['couchbase']['source_url'] = "ftp://10.10.10.10/mirror/couchbase-server-enterprise-3.0.1-centos6.x86_64.rpm"
#default['couchbase']['source_url'] = "https://s3-eu-west-1.amazonaws.com/atex-artifact-store/couchbase-server-enterprise-3.0.1-centos6.x86_64.rpm"
default['couchbase']['install_dir'] = '/srv/couchbase'
default['couchbase']['ftp_active_mode'] = false