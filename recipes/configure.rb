
include_recipe 'jq::default'

install_dir = node['couchbase']['install_dir']
cluster_admin = node['couchbase']['cluster_admin']
cluster_password = node['couchbase']['cluster_password']
bucket_name  = node['couchbase']['bucket_name']
host_name = node['couchbase']['host_name']
data_path = node['couchbase']['data_path']
index_path = node['couchbase']['index_path']
port = node['couchbase']['port']
ram_size = node['couchbase']['ram_size']
bucket_password = node['couchbase']['bucket_password']
replicas = node['couchbase']['replicas']

user = node['couchbase']['user']
group = node['couchbase']['group']



execute 'set-temp-user' do
  retries 20
  retry_delay 2
  command "export CB_REST_USERNAME=#{cluster_admin};export CB_REST_PASSWORD=#{cluster_password}"
  not_if {`/opt/couchbase/bin/couchbase-cli server-list -p #{cluster_password} -u #{cluster_admin} -c 127.0.0.1 | grep 127.0.0.1 | awk '{print $3, $4}'`.gsub("\n","") == 'healthy active' }
end

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

execute 'node init set data path' do
  retries 20
  retry_delay 2
  command "/opt/couchbase/bin/couchbase-cli node-init  --node-init-data-path=#{install_dir}#{data_path} -p #{cluster_password} -u #{cluster_admin} -c #{host_name}"
  not_if { `/opt/couchbase/bin/couchbase-cli server-info -p #{cluster_password} -u #{cluster_admin} -c #{host_name} | /srv/jq --raw-output .storage.hdd[0].path`.gsub("\n","") == "#{install_dir}#{data_path}" }
end

execute 'node init set index path' do
  command "/opt/couchbase/bin/couchbase-cli node-init  --node-init-index-path=#{install_dir}#{index_path} -p #{cluster_password} -u #{cluster_admin} -c #{host_name}"
  not_if {`/opt/couchbase/bin/couchbase-cli server-info -p #{cluster_password} -u #{cluster_admin} -c #{host_name} | /srv/jq --raw-output .storage.hdd[0].index_path`.gsub("\n","") == "#{install_dir}#{index_path}" }
end

execute 'cluster init' do
  retries 20
  retry_delay 2
  command "/opt/couchbase/bin/couchbase-cli cluster-init -p #{cluster_password} -u #{cluster_admin} -c #{host_name}"
  not_if { `/opt/couchbase/bin/couchbase-cli server-list -p #{cluster_password} -u #{cluster_admin} -c #{host_name} | grep 127.0.0.1 | awk '{print $3, $4}'`.gsub("\n","") == 'healthy active'  }
end

execute 'set port' do
  command "/opt/couchbase/bin/couchbase-cli cluster-init -p #{cluster_password} -u #{cluster_admin} --cluster-port=#{port} -c #{host_name}"
  not_if { `/opt/couchbase/bin/couchbase-cli server-info -p #{cluster_password} -u #{cluster_admin} -c #{host_name}| /srv/jq --raw-output .hostname`.gsub("\n","") == "#{host_name}:#{port}" }
end

execute 'set ram' do
  command "/opt/couchbase/bin/couchbase-cli cluster-init -p #{cluster_password} -u #{cluster_admin} --cluster-init-ramsize #{ram_size} -c #{host_name}:#{port}"
  not_if { `/opt/couchbase/bin/couchbase-cli server-info -p #{cluster_password} -u #{cluster_admin} -c #{host_name} | /srv/jq .memoryQuota`.gsub("\n","") == ram_size }
end

execute 'create bucket' do
  command "/opt/couchbase/bin/couchbase-cli bucket-create --bucket #{bucket_name}  --bucket-type couchbase --bucket-replica #{replicas} --bucket-ramsize #{ram_size} -p #{cluster_password} -u #{cluster_admin} --cluster-init-ramsize=#{ram_size} -c #{host_name}:#{port}"
  not_if { `/opt/couchbase/bin/couchbase-cli bucket-list -p #{cluster_password} -u #{cluster_admin} -c #{host_name} | grep #{bucket_name}`.gsub("\n","") == bucket_name }
end

execute 'update bucket ram' do
  command "/opt/couchbase/bin/couchbase-cli bucket-edit --bucket #{bucket_name} --bucket-ramsize #{ram_size} -p #{cluster_password} -u #{cluster_admin} --cluster-init-ramsize=#{ram_size} -c #{host_name}:#{port}"
  only_if { `/opt/couchbase/bin/couchbase-cli bucket-list -p #{cluster_password} -u #{cluster_admin} -c #{host_name} | grep #{bucket_name}`.gsub("\n","") == bucket_name }
  not_if { `/opt/couchbase/bin/couchbase-cli bucket-list -p #{cluster_password} -u #{cluster_admin} -c #{host_name} | grep ramQuota | awk '{print $2}'`.gsub("\n","").to_i / 1024 / 1024 == ram_size.to_i }
end



# # execute 'set-password' do
# #   command "/opt/couchbase/bin/couchbase-cli cluster-init --password=#{password} -c 127.0.0.1"
# # end
# /opt/couchbase/bin/couchbase-cli cluster-init --password=hejhej --user=hejhej -c 127.0.0.1

# /opt/couchbase/bin/couchbase-cli cluster-init-ramsize --password=hejhej --user=hejhej -c 127.0.0.1
# /opt/couchbase/bin/couchbase-cli cluster-init --password=password --user=Administrator -c 127.0.0.1