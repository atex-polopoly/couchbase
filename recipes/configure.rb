require 'json'

include_recipe 'chef-vault'

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

admin_vault_item = chef_vault_item(node['couchbase']['vault'], "#{node.chef_environment}-admin")
bucket_vault_item = chef_vault_item(node['couchbase']['vault'], "#{node.chef_environment}-bucket")

admin_user = admin_vault_item['admin_username']
admin_password = admin_vault_item['admin_password']
bucket_password = bucket_vault_item['bucket_password']

cli = Proc.new { |comm| run_command(comm, admin_user, admin_password) }
cli_json = Proc.new { |comm| JSON.parse(cli.call comm) }
cli_arr = Proc.new { |comm| cli.call(comm).split "\n" }

directory "#{data_path}" do
  owner user
  group group
  mode '0774'
  recursive true
end

directory "#{index_path}" do
  owner user
  group group
  mode '0774'
  recursive true
end

service "couchbase-server" do
  action :stop
  not_if "grep '{indexer_admin_port, 9106}.' /opt/couchbase/etc/couchbase/static_config"
  only_if {File.exist? '/opt/couchbase/etc/couchbase/static_config' }
end

file '/opt/couchbase/var/lib/couchbase/config/config.dat' do
  action :delete
  not_if "grep '{indexer_admin_port, 9106}.' /opt/couchbase/etc/couchbase/static_config"
  only_if {File.exist? '/opt/couchbase/etc/couchbase/static_config' }
end

execute 'custom indexer admin port' do
  command "echo '{indexer_admin_port, 9106}.' >> /opt/couchbase/etc/couchbase/static_config"
  not_if "grep '{indexer_admin_port, 9106}.' /opt/couchbase/etc/couchbase/static_config"
  only_if {File.exist? '/opt/couchbase/etc/couchbase/static_config' }
end

service "couchbase-server" do
  action :start
end

couchbase_cli_command 'node init set data path' do
  admin_user admin_user
  admin_password admin_password
  retries 10
  cli_command "node-init --node-init-data-path=#{data_path}"
  not_if { cli_json.call('server-info')['storage']['hdd'][0]['path'] == data_path }
end


couchbase_cli_command 'node init set index path' do
  admin_user admin_user
  admin_password admin_password
  cli_command "node-init  --node-init-index-path=#{index_path}"
  not_if { cli_json.call('server-info')['storage']['hdd'][0]['index_path'] == index_path }
end


couchbase_cli_command 'cluster init' do
  admin_user admin_user
  admin_password admin_password
  cli_command "cluster-init --cluster-ramsize #{cluster_ram_size} --cluster-index-ramsize #{index_ram_size} --cluster-fts-ramsize #{fts_ram_size} --services=data,index,query,fts"
  not_if { cli_arr.call('server-list').find { |ln| ln.include? '127.0.0.1' }.end_with? 'healthy active' }
end

couchbase_cli_command 'update cluster ram' do
  admin_user admin_user
  admin_password admin_password
  cli_command "cluster-edit --cluster-ramsize #{cluster_ram_size}"
  not_if { cli_json.call('server-info')['memoryQuota'] == cluster_ram_size }
end

couchbase_cli_command 'set index ram' do
  admin_user admin_user
  admin_password admin_password
  cli_command "cluster-edit --cluster-index-ramsize #{index_ram_size}"
  not_if { cli_json.call('server-info')['indexMemoryQuota'] == index_ram_size }
end

couchbase_cli_command 'set fts ram' do
  admin_user admin_user
  admin_password admin_password
  cli_command "cluster-edit --cluster-fts-ramsize #{fts_ram_size}"
  not_if { cli_json.call('server-info')['ftsMemoryQuota'] == fts_ram_size }
end

couchbase_cli_command 'create bucket' do
  admin_user admin_user
  admin_password admin_password
  cli_command "bucket-create --bucket #{bucket_name} --bucket-type couchbase --bucket-ramsize #{bucket_ram_size} --bucket-password '#{bucket_password}'"
  not_if { cli_json.call('bucket-list --output=json').one? { |bucket| bucket['name'] == bucket_name } }
end

couchbase_cli_command 'update bucket ram' do
  admin_user admin_user
  admin_password admin_password
  cli_command "bucket-edit --bucket #{bucket_name} --bucket-ramsize #{bucket_ram_size}"
  only_if { cli_json.call('bucket-list --output=json').one? { |bucket| bucket['name'] == bucket_name } }
  not_if { cli_json.call('bucket-list --output=json').find { |bucket| bucket['name'] == bucket_name }['quota']['ram'] / 1024 /1024 == bucket_ram_size }
end

couchbase_cli_command 'update bucket password' do
  admin_user admin_user
  admin_password admin_password
  cli_command "bucket-edit --bucket #{bucket_name} --bucket-password '#{bucket_password}'"
  only_if { cli_json.call('bucket-list --output=json').one? { |bucket| bucket['name'] == bucket_name } }
  not_if { cli_json.call('bucket-list --output=json').find { |bucket| bucket['name'] == bucket_name }['saslPassword'] == bucket_password }
end
