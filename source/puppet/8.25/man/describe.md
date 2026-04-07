---
layout: default
built_from_commit: bde70bf57e0074f7ac207c903f429bc875d6ba4f
title: 'Man Page: puppet describe'
canonical: "/puppet/latest/man/describe.html"
---

# Man Page: puppet describe

> **NOTE:** This page was generated from the Puppet source code on 2026-04-06 14:55:20 +0200

## NAME
**puppet-describe** - Display help about resource types available to
OpenVox

## SYNOPSIS
Prints help about Puppet resource types, providers, and metaparameters
installed on an OpenVox node.

## USAGE
puppet describe \[-h\|\--help\] \[-s\|\--short\] \[-p\|\--providers\]
\[-l\|\--list\] \[-m\|\--meta\]

## OPTIONS
\--help

:   Print this help text

\--providers

:   Describe providers in detail for each type

\--list

:   List all types

\--meta

:   List all metaparameters

\--short

:   List only parameters without detail

## EXAMPLE
    $ puppet describe --list
    $ puppet describe file --providers
    $ puppet describe user -s -m

## AUTHOR
David Lutterkort

## COPYRIGHT
Copyright (c) 2011 Puppet Inc. Copyright (c) 2024 Vox Pupuli Licensed
under the Apache 2.0 License
