---
stage: Verify
group: Pipeline Execution
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Test with GitLab CI/CD and generate reports in merge requests **(FREE)**

Use GitLab CI/CD to test the changes included in a feature branch. You can also
display reports or link to important information directly from [merge requests](../../user/project/merge_requests/index.md).

| Feature                                                                 | Description |
|-------------------------------------------------------------------------|-------------|
| [Accessibility Testing](accessibility_testing.md)                       | Automatically report A11y violations for changed pages in merge requests. |
| [Browser Performance Testing](browser_performance_testing.md)           | Quickly determine the browser performance impact of pending code changes. |
| [Load Performance Testing](load_performance_testing.md)                 | Quickly determine the server performance impact of pending code changes. |
| [Code Coverage](code_coverage.md)                                       | See code coverage results in the MR, project or group. |
| [Code Quality](code_quality.md)                                         | Analyze your source code quality using the [Code Climate](https://codeclimate.com/) analyzer and show the Code Climate report right in the merge request widget area. |
| [Display arbitrary job artifacts](../yaml/index.md#artifactsexpose_as)  | Configure CI pipelines with the `artifacts:expose_as` parameter to directly link to selected [artifacts](../jobs/job_artifacts.md) in merge requests. |
| [Unit test reports](unit_test_reports.md)                               | Configure your CI jobs to use Unit test reports, and let GitLab display a report on the merge request so that it's easier and faster to identify the failure without having to check the entire job log. |
| [License Scanning](../../user/compliance/license_scanning_of_cyclonedx_files/index.md) | Manage the licenses of your dependencies. |
| [Metrics Reports](metrics_reports.md)                                   | Display the Metrics Report on the merge request so that it's fast and easier to identify changes to important metrics. |
| [Test Coverage visualization](test_coverage_visualization.md)           | See test coverage results for merge requests, in the file diff. |
| [Fail fast testing](fail_fast_testing.md)                               | Run a subset of your RSpec test suite, so failed tests stop the pipeline before the full suite of tests run, saving resources. |

## Security Reports **(ULTIMATE)**

In addition to the reports listed above, GitLab can do many types of [Security reports](../../user/application_security/index.md),
generated by scanning and reporting any vulnerabilities found in your project:

| Feature                                                                                      | Description |
|----------------------------------------------------------------------------------------------|-------------|
| [Container Scanning](../../user/application_security/container_scanning/index.md)            | Analyze your Docker images for known vulnerabilities. |
| [Dynamic Application Security Testing (DAST)](../../user/application_security/dast/index.md) | Analyze your running web applications for known vulnerabilities. |
| [Dependency Scanning](../../user/application_security/dependency_scanning/index.md)          | Analyze your dependencies for known vulnerabilities. |
| [Static Application Security Testing (SAST)](../../user/application_security/sast/index.md)  | Analyze your source code for known vulnerabilities. |
