# Overview

For a long time, it's been known that one could, on occasion, use the following hack to update a single gem
without affecting its dependencies:

    bundle update --source [gem_name]

The trouble is this was a side-effect of some unknown bit of code in the bowels of Bundler. This repo documents
what's going on and includes some code samples to demonstrate different aspects of the issue.

## Background

A good place to start with this issue in general is [this article](http://makandracards.com/makandra/13885-how-to-update-a-single-gem-conservatively)
by Henning Koch discussing various ways to conservatively update a single gem. The last item mentioned in the article
refers to the `--source` hack (which links over to [this other article](http://ilikestuffblog.com/2012/07/01/you-should-update-one-gem-at-a-time-with-bundler-heres-how/)).
[Bundler issue 2016](https://github.com/bundler/bundler/issues/2016) (from July 2012) discusses this topic and also
refers to the `--source` hack. All of these posts refer to the side-effect and inconsistent nature of the hack.

In 2015, a
helpful contributor dove into the code and found what was going on, detailed on
[Bundler issue 3759](https://github.com/bundler/bundler/issues/3759), with a fix for the 'broken' code as well
as an additional patch to attempt to keep the undocumented behavior intact
([Issue/PR 3763](https://github.com/bundler/bundler/pull/3763)).

After doing some hacking on [bundler-patch](https://github.com/livingsocial/bundler-patch), I'd
gained some familiarity with the Bundler codebase and decided to dig in some more, because there didn't seem to be
a suitable explanation around the code identified in those issues as to why it didn't work consistently.

My first theory was perhaps it worked in older versions of Bundler. After some cursory work, the theory seemed to be
confirmed (I didn't get it work with 1.10.x, but did see it work with 1.9.x, but I didn't capture any specifics), so
I wanted to debug into Bundler to
find out what was going on. Here's some code to recreate
the behavior of the above Bundler command line, which set me up to debug in RubyMine:

```ruby
require 'bundler/cli'
require 'bundler/cli/update'

gem_name = 'rack'
options = {:source =>[gem_name]}

Bundler.ui = Bundler::UI::Shell.new
Bundler::CLI::Update.new(options, []).run
```

I was able to debug why it _did_ work down to the same line of code found by `@neoeno`, which is how I backed my
way into discovering issues 3759 and 3763. (Nothing like doing some hard work to discover someone else has
already done it). But now I was confused, because the code enabling the behavior appeared to have gone untouched
until 1.11.x, and even then was kept intact in 1.11.x and 1.12.x.

My first Gemfile case was a simple one with two gems with no runtime dependencies: `rack` and `addressable`. I ran
the hack to just update `rack` using all versions of Bundler from 1.9.10 thru 1.11.2, and every single one of them
worked. This confirmed what I saw in the code across the versions and through [PR 3763](https://github.com/bundler/bundler/pull/3763),
and also revealed that my slap dash experiment with 1.10.x and 1.9.x to begin all of this was inadequate.

My next step was to work with a gem that had some dependencies and start experimenting. I picked the `mail` gem.
