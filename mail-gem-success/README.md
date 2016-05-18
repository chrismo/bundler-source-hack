Execute `ruby run.rb` in this directory.

In this scenario, the `--source` hack will work, because `mime-types` is listed in the Gemfile as
an overall dependency, and this allows this gem to stay locked internally in Bundler.

A normal `bundle update mail` will also update `mime-types` because `bundle update` is designed to
unlock the requested gem(s) and their dependencies, even if a dependencie is also listed as an overall
dependency in the Gemfile.

The documented [CONSERVATIVE UPDATING](http://bundler.io/v1.12/man/bundle-install.1.html#CONSERVATIVE-UPDATING)
behavior with `bundle install` can be demonstrated here to match the `--source` hack. Revert any changes first, then
edit the Gemfile to read `gem 'mail', '~> 2.0'` and run just
`bundle install` to see the same conservative update result without touching `mime-types`.

For extra credit, the gentle reader can attempt to do `bundle update --source treetop` and see that
because _its_ dependency on `polyglot` is _not_ listed in the Gemfile, then the `--source` hack
will not work because `polyglot` will be updated as well. See the [treetop-gem-success](../treetop-gem-success)
example for proof of it working _if_ `polyglot` is listed in the Gemfile.
