def dig(hash, *path)
  path.inject hash do |location, key|
    location.respond_to?(:keys) ? location[key] : nil
  end
end
