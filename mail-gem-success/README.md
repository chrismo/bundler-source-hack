Execute `ruby run.rb` in this directory.

In this scenario, the `--source` hack will work, because `mime-types` is listed in the Gemfile as
a dependency, and this allows this gem to stay locked internally in Bundler.

For extra credit, the gentle reader can attempt to do `bundle update --source treetop` and see that
because _its_ dependency on `polyglot` is _not_ listed in the Gemfile, then the `--source` hack
will not work because `polyglot` will be updated as well. See the [treetop-gem-success](../treetop-gem-success)
example for proof of it working _if_ `polyglot` is listed in the Gemfile.
