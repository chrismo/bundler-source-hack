Execute `ruby run.rb` in this directory.

In this scenario, the `--source` hack will work, because `mime-types` is listed in the Gemfile as
a dependency, and this allows this gem to stay locked internally in Bundler.
