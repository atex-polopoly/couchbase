# Executes Couchbase cli command

default_action :execute
property :cli_command, String, required: true, name_attribute: true
property :host, String, default: '127.0.0.1'
property :bin, String, default: "#{dig(node, 'couchbase', 'install_dir')}/bin"
property :executable, String, default: 'couchbase-cli'
property :port, Integer, default: 0
property :cluster_admin, String
property :cluster_password, String
property :bucket_password, String

action :execute do
  cli_command      = new_resource.cli_command
  bin              = new_resource.bin
  executable       = new_resource.executable
  cluster_admin    = new_resource.cluster_admin
  cluster_password = new_resource.cluster_password
  bucket_password  = new_resource.bucket_password
  port             = new_resource.port
  host             = new_resource.host

  cluster_admin.to_s.empty? ? '' : credetials = "-p #{cluster_password} -u #{cluster_admin}"
  port == 0 ? host = "-c #{host}" : host = "-c #{host}:#{port}" 

  ruby_block "couchbase command" do
    block do
      puts "#{bin}/#{executable} #{cli_command} #{credetials} #{host}"
      result = %x(#{bin}/#{executable} #{cli_command} #{credetials} #{host})
      puts "command output: #{result}"
      abort('ERROR!') if result.start_with? 'ERROR'
    end
  end
end
