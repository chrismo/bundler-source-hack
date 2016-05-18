# Overview

For a long time, it's been known that one could, on occasion, use the following hack to update a single gem
without affecting its dependencies:

    bundle update --source [gem_name]

The trouble is this was a side-effect of some unknown bit of code in the bowels of Bundler. This repo documents
what's going on and includes some code samples to demonstrate different aspects of the issue.

## TL;DR

[Skip to the end!](README.md#why-then-does-the-hack-sometimes-not-work)

## Background

A good place to start with this issue in general is [this article](http://makandracards.com/makandra/13885-how-to-update-a-single-gem-conservatively)
by Henning Koch discussing various ways to conservatively update a single gem. The last item mentioned in the article
refers to the `--source` hack (which links over to [this other article](http://ilikestuffblog.com/2012/07/01/you-should-update-one-gem-at-a-time-with-bundler-heres-how/)).
[Bundler issue 2016](https://github.com/bundler/bundler/issues/2016) (from July 2012) discusses this topic and also
refers to the `--source` hack. All of these posts refer to the side-effect and inconsistent nature of the hack.

In 2015, a helpful contributor ([@neoeno](https://github.com/neoeno)) dove into the code and found what was going on, detailed on
[Bundler issue 3759](https://github.com/bundler/bundler/issues/3759), with a fix for the 'broken' code as well
as an additional patch to attempt to keep the undocumented behavior intact
([Issue/PR 3763](https://github.com/bundler/bundler/pull/3763)).

## Research

After doing some hacking on [bundler-patch](https://github.com/livingsocial/bundler-patch), I'd
gained some familiarity with the Bundler codebase and decided to dig in some more, because there didn't seem to be
a suitable explanation around the code identified in those issues as to why it didn't appear to work consistently.

My first theory was perhaps it worked in older versions of Bundler. After some cursory work, the theory seemed to be
confirmed (I didn't see it work with 1.10.x, but did with 1.9.x, but I didn't capture any specifics), so
I wanted to debug into Bundler to find out what was going on (the [debug.rb](debug.rb) file has some helper code
in it).

I was able to debug why it _did_ work down to the same line of code found by [@neoeno](https://github.com/neoeno),
which is how I backed my
way into finding issues 3759 and 3763. (Nothing like doing some work to discover someone else has
already done it). But now I was confused, because the code enabling the behavior appeared to have gone untouched
until 1.11.x, and even then was kept intact in 1.11.x and 1.12.x.

I started with a simple case, a Gemfile with two gems with no runtime dependencies: `rack` and `addressable`. I ran
the hack to just update `rack` using all versions of Bundler from 1.9.10 thru 1.11.2, and every single one of them
worked. This confirmed what I saw in the code across the versions and through [PR 3763](https://github.com/bundler/bundler/pull/3763),
and also revealed that my slap dash experiment with 1.10.x and 1.9.x to begin all of this was inadequate.

My next step was to work with a gem that had some dependencies and start experimenting. I picked the `mail` gem
and its dependencies. I needed to setup a Gemfile that didn't have a version requirement, but a .lock file that
was pinned to older versions. To do this, I would add dependencies to the Gemfile
with a specific version, run `bundle install`, then remove the version restriction (or sometimes the dependency).
In the process of running `bundle update --source mail` in different combinations, I noticed that even with the same
version of Bundler, sometimes it would only update `mail` and sometimes it update `mail` and other dependencies.
After playing with it I noticed the difference.
Gem dependencies listed in the Gemfile would remain locked and not be updated, otherwise, they'd be up for grabs.

## Examples

There are 3 examples here to re-create the results. I don't know how old a version of Bundler these will work with,
but should be fairly old versions, and definitely 1.9.x through 1.12.x all work.

Each example directory has its own README explaining the specifics.

- [mail-gem-failure](mail-gem-failure) shows a case where the `--source` hack not only updates the `mail` gem but also
its dependent `mime-types` gem.
- [mail-gem-success](mail-gem-success) demonstrates how adding the `mime-types` dependency to the Gemfile allows the
`--source` hack to wok.
- [treetop-gem-success](treetop-gem-success) shows an additional case with other dependencies of the `mail` gem.

## Explanation

When Bundler is spinning up, it reads the contents of the Gemfile and the lockfile and passes that data into a
Definition class. The Definition class will use the Resolver class to resolve all of the dependencies and requirements
and calculate the new version for gems being updated to satisfy all version requirements.
Part of this process needs to determine what gems will remain locked and not have its version changed,
and which are unlocked.

Here are some common use cases with Bundler and the unlocking behavior:

| Description                       | Lock Status                       |
|-----------------------------------|-----------------------------------|
| `bundle install` with no .lock file | No gems are locked / All unlocked |
| `bundle install` with .lock file, after Gemfile edit | Only changed gems unlocked. See [CONSERVATIVE UPDATING](http://bundler.io/v1.12/man/bundle-install.1.html#CONSERVATIVE-UPDATING)        |
| `bundle update [gemname]`           | Only listed gems and their dependencies are unlocked |
| `bundle update`                     | No gems are locked / All unlocked |

What the `--source` hack essentially does is replicate the "conservative update" case of `bundle install` without
having to make a modification to the gem dependency in the Gemfile.

### Deeper Dive

What both the "conservative update" case of `bundle install` and the `--source` hack have in common is when
the Resolver is instantiated, a `last_resolve` is calculated in a method called `converge_locked_specs`
[[source](https://github.com/bundler/bundler/blob/1-11-stable/lib/bundler/definition.rb#L516)]. The purpose of
`last_resolve` is to inform the resolution process of locked gems. The
description of the `converge_locked_specs` method is:

    # Remove elements from the locked specs that are expired. This will most
    # commonly happen if the Gemfile has changed since the lockfile was last
    # generated

(This could also be expanded to say "and not commonly happen when a gem name, instead of a git or path source
[as intended](http://bundler.io/v1.12/man/bundle-update.1.html), is passed to the --source option.")

The method works by building up two arrays, one called (unfortunately, just) `deps` and another called `converged`.
The `deps` array contains any listed dependencies in the Gemfile that are still satisfied by the .lock file - in
other words, any essentially unchanged entries in the Gemfile. `satisfied_deps` might be a better name
for this array.

The `converged` array contains any specifications from the .lock file that still have an unchanged source, rubygems.org
being the most popular source. If the source is different, then it needs to be unlocked for the duration of the
resolution, and this is accomplished first by removing this gem spec from the `converged` array.

This brings us to the [original intent](http://bundler.io/v1.12/man/bundle-update.1.html) of the `--source` switch:
to tell `bundle update` to unlock
a `:git` or `:path` source by name. But due to an old bug, Bundler only checked the contents of the
`--source` option against the gem spec's _name_ (e.g. `mail`) not the name of the gem spec's _source_. This is what
allows the `--source` hack to work. This is what [Issue/PR 3763](https://github.com/bundler/bundler/pull/3763) fixed
(checking the gem spec's source's name) while leaving the now depended upon hack in place (checking the gem spec's name).

Referring to the [mail-gem-success](mail-gem-success) example, in the "conservative update" `bundle install` use case,
here are the values of the `deps` and `converged` arrays:

| deps | converged |
|------|------------|
|            | mail |
| mime-types | mime-types |
|            | polyglot |
|            | treetop |

In this case, the two dependencies in the Gemfile are `mail` and `mime-types`. However, the `mail` entry was modified
in the Gemfile first, so it failed the test for dependencies in the Gemfile
still satisfied by the .lock file, leaving only `mime-types` in the `deps` array.
None of the sources for any 4 of the gems were affected, so they all make the cut for the `converged` array.


In the `--source` hack use case, here are the values of the `deps` and `converged` arrays:

| deps | converged |
|------|------------|
| mail        | |
| mime-types  | mime-types |
|             | polyglot |
|            | treetop |

In this case, the Gemfile wasn't altered, so both `mail` and `mime-types` make it into the `deps` array. All 4 gems
would have made it into the `converged` array, except for the glitchy line of code checking the value of the
`--source` option against the _name_ of the `mail` gem spec, not the name of its source, so the `mail` gem is removed
from the `converged` array.

The `converge_locked_specs` method concludes by doing a mini-resolve of `converged` against `deps` and in both cases,
the result is the same: only `mime-types` comes out into the `last_resolve` variable, which is fed to the
main Resolver instance as the baseline of gems to lock.


### Why Then Does The Hack Sometimes Not Work?

It appears to me now to behave consistently, so I think our expectations may be out of sync with the intended behavior.

It won't work when the dependency we want to stay put isn't listed as an overall dependency in the Gemfile. If it's
not listed at all in the Gemfile, if it's _only_ making an appearance as a dependency of a listed dependency
in the Gemfile (i.e. it only appears in the .lock file), then as we see in the `converge_locked_specs` method previously,
it will never have that gem in the `deps` array and it will never be fed to the Resolver instance as a locked gem.

Or to say it another way, the hack only accidentally mirrors behavior of the conservative `bundle install` case, which
was designed to function only with listed Gemfile dependencies, not all related dependencies.


### When Did This Turn Into a FAQ?

When you started asking questions it would seem.


### What Are We Going To Do About This?

Perhaps I can interest you in checking out my [bundler-patch](https://github.com/livingsocial/bundler-patch) gem?
It's a Bundler plugin designed to provide a lot of options to conservatively update gems in a Bundle. Check
it out and if you love it or dislike it, lemme know. If you hate it, keep that to yourself.
