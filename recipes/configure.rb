require 'json'

include_recipe 'chef-vault'

port = attribute Integer, 'couchbase', 'port'
install_dir = attribute String, 'couchbase', 'install_dir'
bucket_name = attribute String, 'couchbase', 'bucket_name'
data_path = attribute String,  'couchbase', 'data_path'
index_path = attribute String, 'couchbase', 'index_path'
cluster_ram_size = attribute Integer, 'couchbase', 'cluster_ram_size'
index_ram_size = attribute Integer, 'couchbase', 'index_ram_size'
fts_ram_size = attribute Integer, 'couchbase', 'fts_ram_size'
bucket_ram_size = attribute Integer, 'couchbase', 'bucket_ram_size'
master = attribute [TrueClass, FalseClass], 'couchbase', 'master'

user = attribute String, 'couchbase', 'user'
group =  attribute String, 'couchbase', 'group'

vault = attribute String,  'couchbase', 'vault'

admin_vault_item = chef_vault_item(vault, "#{node.chef_environment}-admin")
bucket_vault_item = chef_vault_item(vault, "#{node.chef_environment}-bucket")

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

directory node['couchbase']['log_dir'] do
  owner user
  group group
  mode '755'
end

template'/opt/couchbase/etc/couchbase/static_config' do
  source 'static_config.erb'
  owner user
  group group
  mode '0755'
  variables({
    log_dir: node['couchbase']['log_dir']
  })
  notifies :reload, 'service[couchbase-server]', :delayed
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
  not_if { cli_arr.call('server-list').find { |ln| ln.include?('127.0.0.1') ||  ln.include?("#{node['ipaddress']}") }.end_with? 'healthy active' }
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

slave_url = node['couchbase']['slave_url']
if master && slave_url

  master_adress = "#{slave_url}:#{node['couchbase']['port']}"
  cluster_name = 'slave'

  couchbase_cli_command 'create remote cluster' do
    admin_user admin_user
    admin_password admin_password
    cli_command "xdcr-setup --create --xdcr-cluster-name='#{cluster_name}' --xdcr-hostname='#{master_adress}' --xdcr-username='#{admin_user}' --xdcr-password='#{admin_password}'"
    not_if { cli_json.call('xdcr-setup --list --output=json').any? { |cluster| cluster['name'] == cluster_name } }
  end

  couchbase_cli_command 'edit existing remote cluster' do
    admin_user admin_user
    admin_password admin_password
    cli_command "xdcr-setup --edit --xdcr-cluster-name='#{cluster_name}' --xdcr-hostname='#{master_adress}' --xdcr-username='#{admin_user}' --xdcr-password='#{admin_password}'"
    only_if { cli_json.call('xdcr-setup --list --output=json').any? { |cluster| cluster['name'] == cluster_name } }
    not_if do
      set = cli_json.call('xdcr-setup --list --output=json').find { |cluster| cluster['name'] == cluster_name }.select { |key, value| ['hostname', 'name'].include? key }
      set == {'hostname' => master_adress, 'name' => cluster_name}
    end
  end

  couchbase_cli_command 'remove replication' do
    admin_user admin_user
    admin_password admin_password
    cli_command "xdcr-replicate --create --xdcr-cluster-name='#{cluster_name}' --xdcr-from-bucket='#{bucket_name}' --xdcr-to-bucket='#{bucket_name}'"
    not_if do
      uuid = cli_json.call('xdcr-setup --list --output=json').find { |cluster| cluster['name'] == cluster_name }['uuid']
      replication =
        cli_arr.call('xdcr-replicate --list')
               .slice_before { |s| s.start_with? 'stream' }
               .map { |arr| arr.map { |l| l.delete ' ' }.map { |l| l.split ':' }.flatten }
               .map { |arr| Hash[*arr] }
               .find { |hash| hash['streamid'].start_with? uuid }
    end
  end

  couchbase_cli_command 'create replication' do
    admin_user admin_user
    admin_password admin_password
    cli_command "xdcr-replicate --create --xdcr-cluster-name='#{cluster_name}' --xdcr-from-bucket='#{bucket_name}' --xdcr-to-bucket='#{bucket_name}'"
    not_if do
      uuid = cli_json.call('xdcr-setup --list --output=json').find { |cluster| cluster['name'] == cluster_name }['uuid']
      replication =
        cli_arr.call('xdcr-replicate --list')
               .slice_before { |s| s.start_with? 'stream' }
               .map { |arr| arr.map { |l| l.delete ' ' }.map { |l| l.split ':' }.flatten }
               .map { |arr| Hash[*arr] }
               .find { |hash| hash['streamid'].start_with? uuid }

      !replication.nil?
    end
  end
end
