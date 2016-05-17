Execute `ruby run.rb` in this directory.

In this scenario, the `--source` hack will _not_ work, because `mime-types` is _not_ listed in the Gemfile as
a dependency, and thus it will be unlocked internally in Bundler as an unlisted dependency of `mail`, and so
both gems will be updated.
