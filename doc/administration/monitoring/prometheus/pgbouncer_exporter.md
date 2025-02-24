---
stage: Data Stores
group: Database
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# PgBouncer exporter **(FREE SELF)**

The [PgBouncer exporter](https://github.com/prometheus-community/pgbouncer_exporter) enables
you to measure various [PgBouncer](https://www.pgbouncer.org/) metrics.

For installations from source you must install and configure it yourself.

To enable the PgBouncer exporter:

1. [Enable Prometheus](index.md#configuring-prometheus).
1. Edit `/etc/gitlab/gitlab.rb`.
1. Add (or find and uncomment) the following line, making sure it's set to `true`:

   ```ruby
   pgbouncer_exporter['enable'] = true
   ```

1. Save the file and [reconfigure GitLab](../../restart_gitlab.md#reconfigure-a-linux-package-installation)
   for the changes to take effect.

Prometheus begins collecting performance data from the PgBouncer exporter
exposed at `localhost:9188`.

The PgBouncer exporter is enabled by default if the
[`pgbouncer_role`](https://docs.gitlab.com/omnibus/roles/#postgresql-roles)
role is enabled.
