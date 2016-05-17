def cmd(msg, cmd)
  puts "\n*** #{msg}: `#{cmd}` ***"
  puts `#{cmd}`
  puts
end
