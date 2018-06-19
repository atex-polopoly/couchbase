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
  Chef::Log.info(command)
  out = %x(#{command})
  Chef::Log.info(out)
  out
  #raise
end


def attribute(types, *path)
  var = path.inject(node, :[])
  types = Array(types) << NilClass
  unless types.any? { |type| var.is_a? type }
    e = TypeError.new "node#{path.map {|s| "[#{s}]" }.reduce(:+)} was of type #{var.class}, expected: #{types}"
    e.set_backtrace caller
    raise e
  end
  var
end
