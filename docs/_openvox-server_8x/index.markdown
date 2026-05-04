---
layout: default
title: "Puppet Server: Index"
canonical: "/puppetserver/latest/"
---

Puppet Server is the next-generation application for managing Puppet agents.

> **Note:** For information about configuring and tuning settings specific to [Puppet Enterprise](https://puppet.com/docs/pe/), see
> [its documentation](https://puppet.com/docs/pe/latest/configuring/config_puppetserver.html).

- [**About OpenVox Server**](./services_puppetserver.html)
  - [Release notes](./release_notes.html)
  - [Deprecated features](./deprecated_features.html)
  - [Notable differences vs. the Apache/Passenger stack](./puppetserver_vs_passenger.html)
  - [Compatibility with Puppet agent](./compatibility_with_puppet_agent.html)
- [**Installing Puppet Server**](./install_from_packages.html)
- [**Configuring Puppet Server**](./configuration.html)
  - [global.conf](./config_file_global.html)
  - [webserver.conf](./config_file_webserver.html)
  - [web-routes.conf](./config_file_web-routes.html)
  - [puppetserver.conf](./config_file_puppetserver.html)
  - [auth.conf](./config_file_auth.html)
    - [Migrating deprecated authentication rules](./config_file_auth_migration.html)
  - [metrics.conf](./config_file_metrics.html)
  - [logback.xml](./config_file_logbackxml.html)
    - [Advanced logging configuration](./config_logging_advanced.html)
  - [master.conf](./config_file_master.html) (deprecated)
  - [ca.conf](./config_file_ca.html)
  - [Differing behavior in puppet.conf](./puppet_conf_setting_diffs.html)
- **Using and extending Puppet Server**
  - [Subcommands](./subcommands.html)
  - [Using Ruby gems](./gems.html)
  - [Using an external certificate authority](./external_ca_configuration.html)
  - [External SSL termination](./external_ssl_termination.html)
  - [Monitoring Puppet Server metrics](./puppet_server_metrics.html)
    - [HTTP client metrics](./http_client_metrics.html)
  - [Tuning guide](./tuning_guide.html)
  - [Applying metrics to improve performance](./puppet_server_metrics_performance.html)
  - [Scaling Puppet Server](./scaling_puppet_server.html)
  - [Restarting Puppet Server](./restarting.html)
- **Known issues and workarounds**
  - [Known issues](./known_issues.html)
  - [SSL problems with load-balanced PuppetDB servers ("Server Certificate Change" error)](./ssl_server_certificate_change_and_virtual_ips.html)
- **Administrative API endpoints**
  - [Environment cache](./admin-api/v1/environment-cache.html)
  - [JRuby pool](./admin-api/v1/jruby-pool.html)
- **Server-specific Puppet API endpoints**
  - [Environment classes](./puppet-api/v3/environment_classes.html)
  - [Environment modules](./puppet-api/v3/environment_modules.html)
  - [Static file content](./puppet-api/v3/static_file_content.html)
- **Status API endpoints**
  - [Status services](./status-api/v1/services.html)
  - [Simple status](./status-api/v1/simple.html)
- **Metrics API endpoints**
  - [v1 metrics](./metrics-api/v1/metrics_api.html)
  - [v2 (Jolokia) metrics](./metrics-api/v2/metrics_api.html)
- **Developer information**
  - [Debugging](./dev_debugging.html)
  - [Running from source](./dev_running_from_source.html)
  - [Tracing code events](./dev_trace_func.html)
