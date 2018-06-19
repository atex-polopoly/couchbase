# Executes Couchbase cli command

default_action :execute
property :cli_command, String, required: true, name_attribute: true
property :host, String
property :bin, String
property :executable, String
property :port, Integer
property :admin_user, String
property :admin_password, String

action :execute do
  command = new_resource.cli_command
  params = []
  params << command
  params << new_resource.admin_user
  params << new_resource.admin_password
  params << new_resource.host unless new_resource.host.nil?
  params << new_resource.port unless new_resource.port.nil?
  params << new_resource.bin unless new_resource.bin.nil?
  params << new_resource.executable unless new_resource.executable.nil?


  ruby_block 'run' do
      block do
      output = run_command(*params)
      raise(output) if output.start_with? 'ERROR'
      printf("\n%s", output)
    end
  end
  new_resource.updated_by_last_action true
end
