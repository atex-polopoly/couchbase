include_recipe 'jq::default'
include_recipe 'chef-vault'

host_name = node['couchbase']['host_name']
port = node['couchbase']['port']
install_dir = node['couchbase']['install_dir']
bucket_name  = node['couchbase']['bucket_name']
data_path = node['couchbase']['data_path']
index_path = node['couchbase']['index_path']
cluster_ram_size = node['couchbase']['cluster_ram_size']
index_ram_size = node['couchbase']['index_ram_size']
fts_ram_size = node['couchbase']['fts_ram_size']
bucket_ram_size = node['couchbase']['bucket_ram_size']

user = node['couchbase']['user']
group = node['couchbase']['group']

vault = chef_vault_item(node['couchbase']['vault'], node.chef_environment)

cli = "#{install_dir}/bin/couchbase-cli"

cluster_admin = "'#{vault['username']}'"
cluster_password = "'#{vault['password']}'"
bucket_password = "'#{vault['bucket_password']}'"


credetials = "-p #{cluster_password} -u #{cluster_admin}"

directory "#{install_dir}#{data_path}" do
  owner user
  group group
  mode '0774'
end


directory "#{install_dir}#{index_path}" do
  owner user
  group group
  mode '0774'
end

couchbase_cli_command 'node init set data path' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  retries 10
  cli_command "node-init --node-init-data-path=#{install_dir}#{data_path}"
  not_if { `#{cli} server-info #{credetials} -c #{host_name} | /srv/jq --raw-output .storage.hdd[0].path`.gsub("\n","") == "#{install_dir}#{data_path}" }
end


couchbase_cli_command 'node init set index path' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  cli_command "node-init  --node-init-index-path=#{install_dir}#{index_path}"
  not_if { `#{cli} server-info #{credetials} -c #{host_name} | /srv/jq --raw-output .storage.hdd[0].index_path`.gsub("\n","") == "#{install_dir}#{index_path}" }
end


couchbase_cli_command 'cluster init' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  cli_command "cluster-init --cluster-ramsize #{cluster_ram_size} --cluster-index-ramsize #{index_ram_size} --cluster-fts-ramsize #{fts_ram_size} --services=data,index,query,fts "
  not_if { `#{cli} server-list #{credetials} -c #{host_name} | grep 127.0.0.1 | awk '{print $3, $4}'`.gsub("\n","") == 'healthy active'  }
end

couchbase_cli_command 'update cluster ram' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  cli_command "cluster-edit --cluster-ramsize #{cluster_ram_size}"
  not_if { `#{cli} server-info #{credetials} -c #{host_name} | /srv/jq .memoryQuota`.gsub("\n","") == cluster_ram_size  }
end

couchbase_cli_command 'set index ram' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  cli_command "cluster-edit --cluster-index-ramsize #{index_ram_size} "
  not_if { `#{cli} server-info #{credetials} -c #{host_name} | /srv/jq .indexMemoryQuota`.gsub("\n","") == index_ram_size  }
end

couchbase_cli_command 'set fts ram' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  cli_command "cluster-edit --cluster-fts-ramsize #{fts_ram_size} "
  not_if { `#{cli} server-info #{credetials} -c #{host_name} | /srv/jq .ftsMemoryQuota`.gsub("\n","") == fts_ram_size  }
end

couchbase_cli_command 'create bucket' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  cli_command "bucket-create --bucket #{bucket_name} --bucket-type couchbase --bucket-ramsize #{bucket_ram_size} --bucket-password #{bucket_password}"
  not_if { `#{cli} bucket-list #{credetials} -c #{host_name}:#{port} | grep #{bucket_name}`.gsub("\n","") == bucket_name }
end

couchbase_cli_command 'update bucket ram' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  cli_command "bucket-edit --bucket #{bucket_name} --bucket-ramsize #{bucket_ram_size}"
  only_if { `#{cli} bucket-list #{credetials} -c #{host_name}:#{port} | grep #{bucket_name}`.gsub("\n","") == bucket_name }
  not_if { `#{cli} bucket-list #{credetials} -c #{host_name}:#{port} | grep ramQuota | awk '{print $2}'`.gsub("\n","").to_i / 1024 / 1024 == bucket_ram_size.to_i }
end

couchbase_cli_command 'update bucket password' do
  cluster_admin cluster_admin
  cluster_password cluster_password
  cli_command "bucket-edit --bucket #{bucket_name} --bucket-password #{bucket_password}"
  only_if { `#{cli} bucket-list #{credetials} -c #{host_name}:#{port} | grep #{bucket_name}`.gsub("\n","") == bucket_name }
  not_if { `#{cli} bucket-list #{credetials} -c #{host_name} | grep saslPassword | awk '{print $2}'`.gsub("\n","") == bucket_password[1...-1] }
end

