Execute `ruby run.rb` in this directory.

In this scenario, the `--source` hack will work, because `polyglot` is listed in the Gemfile as
a dependency, and this allows this gem to stay locked internally in Bundler, so only `treetop`
will be upgraded. Also because `polyglot` will stay locked, the available version information
fed to Molinillo will restricte the available `treetop` versions to within a compatible range,
meaning treetop will only be upgraded to version 1.4.3.
