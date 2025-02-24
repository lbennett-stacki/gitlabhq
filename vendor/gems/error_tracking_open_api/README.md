# Generated by `rake gems:error_tracking_open_api:generate` on 2023-06-08

See https://gitlab.com/gitlab-org/gitlab/-/blob/master/doc/development/rake_tasks.md#update-openapi-client-for-error-tracking-feature

# error_tracking_open_api

ErrorTrackingOpenAPI - the Ruby gem for the Error Tracking REST API

This schema describes the API endpoints for the error tracking feature

This SDK is automatically generated by the [OpenAPI Generator](https://openapi-generator.tech) project:

- API version: 0.0.1
- Package version: 1.0.0
- Build package: org.openapitools.codegen.languages.RubyClientCodegen

## Installation

### Build a gem

To build the Ruby code into a gem:

```shell
gem build error_tracking_open_api.gemspec
```

Then either install the gem locally:

```shell
gem install ./error_tracking_open_api-1.0.0.gem
```

(for development, run `gem install --dev ./error_tracking_open_api-1.0.0.gem` to install the development dependencies)

or publish the gem to a gem hosting service, e.g. [RubyGems](https://rubygems.org/).

Finally add this to the Gemfile:

    gem 'error_tracking_open_api', '~> 1.0.0'

### Install from Git

If the Ruby gem is hosted at a git repository: https://github.com/GIT_USER_ID/GIT_REPO_ID, then add the following in the Gemfile:

    gem 'error_tracking_open_api', :git => 'https://github.com/GIT_USER_ID/GIT_REPO_ID.git'

### Include the Ruby code directly

Include the Ruby code directly using `-I` as follows:

```shell
ruby -Ilib script.rb
```

## Getting Started

Please follow the [installation](#installation) procedure and then run the following code:

```ruby
# Load the gem
require 'error_tracking_open_api'

# Setup authorization
ErrorTrackingOpenAPI.configure do |config|
  # Configure API key authorization: internalToken
  config.api_key['internalToken'] = 'YOUR API KEY'
  # Uncomment the following line to set a prefix for the API key, e.g. 'Bearer' (defaults to nil)
  # config.api_key_prefix['internalToken'] = 'Bearer'
end

api_instance = ErrorTrackingOpenAPI::ErrorsApi.new
project_id = 56 # Integer | ID of the project where the error was created
fingerprint = 56 # Integer | ID of the error that needs to be updated deleted

begin
  #Get information about the error
  result = api_instance.get_error(project_id, fingerprint)
  p result
rescue ErrorTrackingOpenAPI::ApiError => e
  puts "Exception when calling ErrorsApi->get_error: #{e}"
end

```

## Documentation for API Endpoints

All URIs are relative to *https://localhost/errortracking/api/v1*

Class | Method | HTTP request | Description
------------ | ------------- | ------------- | -------------
*ErrorTrackingOpenAPI::ErrorsApi* | [**get_error**](docs/ErrorsApi.md#get_error) | **GET** /projects/{projectId}/errors/{fingerprint} | Get information about the error
*ErrorTrackingOpenAPI::ErrorsApi* | [**list_errors**](docs/ErrorsApi.md#list_errors) | **GET** /projects/{projectId}/errors | List of errors
*ErrorTrackingOpenAPI::ErrorsApi* | [**list_events**](docs/ErrorsApi.md#list_events) | **GET** /projects/{projectId}/errors/{fingerprint}/events | Get information about the events related to the error
*ErrorTrackingOpenAPI::ErrorsApi* | [**update_error**](docs/ErrorsApi.md#update_error) | **PUT** /projects/{projectId}/errors/{fingerprint} | Update the status of the error
*ErrorTrackingOpenAPI::ErrorsV2Api* | [**get_stats_v2**](docs/ErrorsV2Api.md#get_stats_v2) | **GET** /api/0/organizations/{groupId}/stats_v2 | Stats of events received for the group
*ErrorTrackingOpenAPI::ErrorsV2Api* | [**list_errors_v2**](docs/ErrorsV2Api.md#list_errors_v2) | **GET** /api/0/organizations/{groupId}/issues/ | List of errors(V2)
*ErrorTrackingOpenAPI::ErrorsV2Api* | [**list_projects**](docs/ErrorsV2Api.md#list_projects) | **GET** /api/0/organizations/{groupId}/projects/ | List of projects
*ErrorTrackingOpenAPI::EventsApi* | [**list_events**](docs/EventsApi.md#list_events) | **GET** /projects/{projectId}/errors/{fingerprint}/events | Get information about the events related to the error
*ErrorTrackingOpenAPI::EventsApi* | [**projects_api_project_id_envelope_post**](docs/EventsApi.md#projects_api_project_id_envelope_post) | **POST** /projects/api/{projectId}/envelope | Ingestion endpoint for error events sent from client SDKs
*ErrorTrackingOpenAPI::EventsApi* | [**projects_api_project_id_store_post**](docs/EventsApi.md#projects_api_project_id_store_post) | **POST** /projects/api/{projectId}/store | Ingestion endpoint for error events sent from client SDKs
*ErrorTrackingOpenAPI::MessagesApi* | [**list_messages**](docs/MessagesApi.md#list_messages) | **GET** /projects/{projectId}/messages | List of messages
*ErrorTrackingOpenAPI::ProjectsApi* | [**delete_project**](docs/ProjectsApi.md#delete_project) | **DELETE** /projects/{id} | Deletes all project related data. Mostly for testing purposes and later for production to clean updeleted projects.


## Documentation for Models

 - [ErrorTrackingOpenAPI::Error](docs/Error.md)
 - [ErrorTrackingOpenAPI::ErrorEvent](docs/ErrorEvent.md)
 - [ErrorTrackingOpenAPI::ErrorStats](docs/ErrorStats.md)
 - [ErrorTrackingOpenAPI::ErrorUpdatePayload](docs/ErrorUpdatePayload.md)
 - [ErrorTrackingOpenAPI::ErrorV2](docs/ErrorV2.md)
 - [ErrorTrackingOpenAPI::MessageEvent](docs/MessageEvent.md)
 - [ErrorTrackingOpenAPI::Project](docs/Project.md)
 - [ErrorTrackingOpenAPI::StatsObject](docs/StatsObject.md)
 - [ErrorTrackingOpenAPI::StatsObjectGroupInner](docs/StatsObjectGroupInner.md)


## Documentation for Authorization


### internalToken


- **Type**: API key
- **API key parameter name**: Gitlab-Error-Tracking-Token
- **Location**: HTTP header

