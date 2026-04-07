---
layout: default
built_from_commit: bde70bf57e0074f7ac207c903f429bc875d6ba4f
title: 'Resource Type: whit'
canonical: "/puppet/latest/types/whit.html"
---

# Resource Type: whit

> **NOTE:** This page was generated from the Puppet source code on 2026-04-06 14:55:44 +0200



## whit

* [Attributes](#whit-attributes)

### Description {#whit-description}

Whits are internal artifacts of Puppet's current implementation, and
Puppet suppresses their appearance in all logs. We make no guarantee of
the whit's continued existence, and it should never be used in an actual
manifest. Use the `anchor` type from the puppetlabs-stdlib module if you
need arbitrary whit-like no-op resources.

### Attributes {#whit-attributes}

<pre><code>whit { 'resource title':
  <a href="#whit-attribute-name">name</a> =&gt; <em># <strong>(namevar)</strong> The name of the whit, because it must have...</em>
  # ...plus any applicable <a href="https://puppet.com/docs/puppet/latest/metaparameter.html">metaparameters</a>.
}</code></pre>


#### name {#whit-attribute-name}

_(**Namevar:** If omitted, this attribute's value defaults to the resource's title.)_

The name of the whit, because it must have one.

([↑ Back to whit attributes](#whit-attributes))





