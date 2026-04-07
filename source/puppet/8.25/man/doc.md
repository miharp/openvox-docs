---
layout: default
built_from_commit: bde70bf57e0074f7ac207c903f429bc875d6ba4f
title: 'Man Page: puppet doc'
canonical: "/puppet/latest/man/doc.html"
---

# Man Page: puppet doc

> **NOTE:** This page was generated from the Puppet source code on 2026-04-06 14:55:20 +0200

## NAME
**puppet-doc** - Generate Puppet references for OpenVox

## SYNOPSIS
Generates a reference for all Puppet types. Largely meant for internal
use. (Deprecated)

## USAGE
puppet doc \[-h\|\--help\] \[-l\|\--list\] \[-r\|\--reference
*reference-name*\]

## DESCRIPTION
This deprecated command generates a Markdown document to stdout
describing all installed Puppet types or all allowable arguments to
puppet executables. It is largely meant for internal use and is used to
generate the reference documents which can be posted to a website.

For Puppet module documentation (and all other use cases) this command
has been superseded by the \"puppet-strings\" module - see
https://github.com/puppetlabs/puppetlabs-strings for more information.

This command (puppet-doc) will be removed once the puppetlabs internal
documentation processing pipeline is completely based on puppet-strings.

## OPTIONS
\--help

:   Print this help message

\--reference

:   Build a particular reference. Get a list of references by running
    \'puppet doc \--list\'.

## EXAMPLE
    $ puppet doc -r type > /tmp/type_reference.markdown

## AUTHOR
Luke Kanies

## COPYRIGHT
Copyright (c) 2011 Puppet Inc. Copyright (c) 2024 Vox Pupuli Licensed
under the Apache 2.0 License
