# Workflow for genrating reference

There are two generated ferefences:

1. from openfact
1. from opnvox-agent

## OpenFact

From OpenFact we collect:

1. CLI
1. Core Facts

## OpenVox Agent

From OpenVox agent we fetch

1. bundled types and providers
1. bundled functions

## Workflow

1. Rakefile

### Rakefile

#### OpenFact

`PuppetReferences.build_facter_references(ENV.fetch('VERSION', nil))`

#### build_facter_references

Building references

```ruby
references = [
  PuppetReferences::Facter::CoreFacts,
  PuppetReferences::Facter::FacterCli
]
```

Repo action

```ruby
repo = PuppetReferences::Repo.new('openfact', FACTER_DIR)
real_commit = repo.checkout(commit)
repo.update_bundle
```

1. clone openfact repo into a local dir
1. switches to provided version
1. update all tags (fetch)
1. runs bundle install


```ruby
build_from_list_of_classes(references, real_commit)
```

##### Core Facts

1. executes ruby <openfact>/lib/docs/generate.rb
1. adds header data + preamble + data
1. writes core_facts.md file

##### CLI

1. runs bundle update in openfact
1. runs bundle exec facter man
1. uses PandDoc Ruby to convert man to markdown
1. writs cli.md

#### build puppet reference

```ruby
references = [
      PuppetReferences::Puppet::Man,
      PuppetReferences::Puppet::PuppetDoc,
      PuppetReferences::Puppet::Type,
      PuppetReferences::Puppet::TypeStrings,
      PuppetReferences::Puppet::Functions,
    ]
```

1. Reads config - can be removed
1. Clones repo
1. switch to version
1. run bundle install
1. build_from_list_of_classes

##### Man



##### PuppetDoc

##### Type

##### TpeStrings

##### Functions