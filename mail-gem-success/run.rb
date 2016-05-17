require_relative '../lib'

puts File.read('README.md')

cmd 'Installing the original bundle', 'bundle install'
cmd 'Updating just the mail gem', 'bundle update --source mail'
