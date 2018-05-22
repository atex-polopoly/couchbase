def dig(hash, *path)
  path.inject hash do |location, key|
    location.respond_to?(:keys) ? location[key] : nil
  end
end

def run_command(command,
                user,
                password,
                host = '127.0.0.1',
                port = nil,
                bin = dig(node, 'couchbase', 'install_dir') + '/bin',
                executable = 'couchbase-cli')
  credentials = "-p '#{password}' -u '#{user}'" unless user.nil?

  host = "#{host}:#{port}" unless port.nil?
  host = "-c '#{host}'"

  command = "'#{bin}/#{executable}' #{command} #{credentials} #{host}"
  %x(#{command})
  #raise
end

