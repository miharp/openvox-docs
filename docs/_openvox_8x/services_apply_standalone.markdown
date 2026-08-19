---
layout: default
title: "Standalone workflows with Puppet apply"
---

[apply]: services_apply.html
[architecture]: architecture.html#the-stand-alone-architecture
[tradeoffs]: architecture.html#differences-between-agent-server-and-stand-alone
[pluginsync]: plugins_in_modules.html#auto-download-of-agent-side-plug-ins-pluginsync
[external facts]: /openfact/latest/custom_facts.html#external-facts
[trusted facts]: lang_facts_and_builtin_vars.html#trusted-facts
[modulepath]: dirs_modulepath.html
[vardir]: dirs_vardir.html
[environments]: environments_about.html
[install]: install_pre.html
[template]: https://github.com/OpenVoxProject/control-repo-template
[controlrepo]: https://github.com/voxpupuli/controlrepo
[controlrepo site.pp]: https://github.com/voxpupuli/controlrepo/blob/master/manifests/site.pp
[controlrepo readme]: https://github.com/voxpupuli/controlrepo#hetzner-cloud-cloud-init-userdata
[r10k]: https://github.com/puppetlabs/r10k

In a [standalone deployment][architecture] (often called "masterless"), each node compiles and applies its own catalog with [Puppet apply][apply] instead of an agent requesting catalogs from a server. This is the normal mode for three situations:

* **Bootstrapping the first node of a new deployment.** The node that will become your OpenVox Server can't get its configuration from a server that doesn't exist yet, so you apply the control repository directly.
* **Disposable test environments.** Lab VMs, containers, and CI jobs can apply a control repository checkout directly, with no server or certificate setup.
* **Small single-node setups.** A node that only manages itself doesn't need the agent-server infrastructure.

This page shows how to apply a control repository standalone and how to bootstrap the first node of a fleet, then explains how
module plug-ins load without a server and documents the plug-in cache pattern carried by the
[Vox Pupuli control repository][controlrepo]. For Puppet apply's general behavior (logging, reporting, scheduling), see
[the Puppet apply service page][apply], and for the trade-offs against agent-server, see the [architecture overview][tradeoffs].

## Apply a control repository standalone

Before you begin, [install the openvox-agent package][install] on the node and clone your control repository onto it; if you're starting from scratch, the [OpenVox control repository template][template] provides the layout these steps assume. The steps below use paths relative to the control repository checkout.

1. Install the control repository's Puppetfile modules with [r10k][]:

   ```console
   sudo /opt/puppetlabs/puppet/bin/gem install --no-document r10k
   cd /path/to/control-repo
   sudo /opt/puppetlabs/puppet/bin/r10k puppetfile install --verbose
   ```

   This resolves the `Puppetfile` into the `modules/` directory of the checkout.

2. Apply the main manifest, telling Puppet apply where everything lives:

   ```console
   sudo puppet apply manifests/site.pp \
     --hiera_config hiera.yaml \
     --modulepath site-modules:modules \
     --show_diff
   ```

   Adjust `site-modules:modules` to match your control repository's layout; it must include every directory that contains modules, or plug-ins from the omitted modules won't load. In scripts and CI, add `--detailed-exitcodes`, and treat exit code 2 (changes applied) as success alongside 0.

The node is now managed entirely from the local checkout: rerun step 1 whenever the Puppetfile changes and step 2 to converge.

As an alternative to passing paths on every run, you can deploy the control repository into
`/etc/puppetlabs/code/environments/production` with `r10k deploy environment --modules` and apply its `manifests/site.pp`
without the `--hiera_config` and `--modulepath` arguments. The
[Vox Pupuli control repository's cloud-init example][controlrepo readme] scripts this deployed-environment variant.

## Bootstrap the first node in two phases

When the node being bootstrapped is your future OpenVox Server, applying the full role from a throwaway checkout is undesirable: you want the real configuration to come from a properly deployed environment. The [Vox Pupuli control repository's cloud-init example][controlrepo readme] splits the bootstrap in two:

1. From the initial checkout, apply only the tagged bootstrap resources:

   ```console
   sudo puppet apply /root/control-repo/manifests/site.pp \
     --modulepath /root/control-repo/modules:/root/control-repo/site \
     --hiera_config /root/control-repo/hiera.yaml \
     --tags r10k,hacked_pluginsync
   ```

   This configures r10k and populates the plug-in cache (the `hacked_pluginsync` tag belongs to the
   [cache-sync resource](#keep-the-plug-in-cache-in-sync) described below). Note that `--tags` limits which resources are
   *applied*, not what is compiled: the full catalog must still compile, so the checkout needs its Puppetfile modules installed
   and its Hiera data reachable, exactly as in [Apply a control repository standalone](#apply-a-control-repository-standalone).

2. Deploy the real environment with the r10k configuration from phase 1, then apply from it:

   ```console
   sudo /opt/puppetlabs/puppet/bin/r10k deploy environment --modules --verbose
   sudo puppet apply /etc/puppetlabs/code/environments/production/manifests/site.pp
   ```

Once the node's own role includes the OpenVox Server profile, subsequent runs can switch to `puppet agent -t` against the freshly configured server, and the cache-sync resource's [`$trusted['authenticated']` guard](#keep-the-plug-in-cache-in-sync) keeps the bootstrap resources out of those agent runs automatically.

## How plug-ins load without a server

On agent-managed nodes, [pluginsync][] downloads plug-ins (custom facts, resource types, and providers) from the server into the
agent's cache before each run. Puppet apply doesn't need a sync phase: it loads plug-ins directly from the [modulepath][] of the
environment it's applying. Ruby custom facts and [external facts][] are added to OpenFact's search path from every module, and
functions, resource types, and providers load through the same module loaders OpenVox Server uses. If every module is on the
modulepath for the run, whether from a deployed [environment][environments] or an explicit `--modulepath`, all of its plug-ins
are available, including during catalog compilation and in `--noop` runs.

If a module's custom fact comes back `undef` under Puppet apply, the modulepath was wrong or incomplete for that run. The two
common causes are Puppetfile modules that haven't been installed yet (run r10k first, as shown above) and a `--modulepath` that
lists only some of the directories containing modules. Fix the invocation rather than working around the missing fact.

What a standalone run does *not* do is populate the plug-in cache in the [cache directory (vardir)][vardir]. The apply run itself
never needs the cache, but anything else on the node asking for module plug-ins does. When the run relies on an explicit
`--modulepath`, every command that doesn't repeat those flags is blind to the modules: `facter -p` and `puppet facts` come back
without module facts, `puppet lookup --explain` interpolates `undef` into hierarchy levels that use them and walks the wrong
paths, and `puppet resource` can't find custom types. Even with the repository deployed as the default environment, bare
`facter -p` reads the cache rather than the modulepath and won't see module facts, and neither will the monitoring checks and
scripts that shell out to it. The [file resource pattern below](#keep-the-plug-in-cache-in-sync) closes that gap.

## Keep the plug-in cache in sync

The [Vox Pupuli control repository's site.pp][controlrepo site.pp] opens with a resource that replicates pluginsync as part of the catalog:

```puppet
# hack pluginsync as file resource. only required for `puppet apply` usage
if $trusted['authenticated'] == 'local' {
  file { $settings::libdir:
    ensure  => directory,
    source  => 'puppet:///plugins', # lint:ignore:puppet_url_without_modules
    recurse => true,
    purge   => true,
    backup  => false,
    noop    => false,
    tag     => 'hacked_pluginsync',
  }
}
```

This does not affect the run that applies it: facts are resolved and the catalog is compiled before any resource is applied,
and as described above, the compile already gets its plug-ins from the modulepath. What it does is copy every module's
plug-ins into the same cache directory that pluginsync maintains on agent-managed nodes, so that anything reading the cache
after the run, such as `facter -p`, sees the same facts an agent-managed node would.

Two details matter if you adopt it. The `$trusted['authenticated'] == 'local'` guard is true only for catalogs compiled locally by Puppet apply
(see [trusted facts][]); on agent-managed nodes the agent itself manages this directory during pluginsync, and an unguarded copy of this
resource conflicts with it, so never deploy it unguarded to a mixed fleet. The `tag` lets a bootstrap script apply just this resource
with `--tags`, as shown in [Bootstrap the first node in two phases](#bootstrap-the-first-node-in-two-phases).

External facts have a parallel mount and cache directory. If your modules ship [external facts][] and you need them visible to cache readers too, add a second file resource inside the same guard, with `$settings::pluginfactdest` as the title and `puppet:///pluginfacts` as the source.

## Working examples

* [OpenVoxProject/control-repo-template][template]: the template for starting a new control repository. It applies standalone as shipped, and the invocation in [Apply a control repository standalone](#apply-a-control-repository-standalone) matches its layout.
* [voxpupuli/controlrepo][controlrepo]: the control repository managing Vox Pupuli's own fleet. Its [site.pp][controlrepo site.pp] carries the plug-in cache resource, and its [README][controlrepo readme] shows the two-phase bootstrap as both a shell script and cloud-init userdata.
