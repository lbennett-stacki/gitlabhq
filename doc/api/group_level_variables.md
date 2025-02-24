---
stage: Verify
group: Pipeline Security
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Group-level Variables API **(FREE)**

## List group variables

Get list of a group's variables.

```plaintext
GET /groups/:id/variables
```

| Attribute | Type           | Required | Description |
|-----------|----------------|----------|-------------|
| `id`      | integer/string | Yes      | The ID of a group or [URL-encoded path of the group](rest/index.md#namespaced-path-encoding) |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/1/variables"
```

```json
[
    {
        "key": "TEST_VARIABLE_1",
        "variable_type": "env_var",
        "value": "TEST_1",
        "protected": false,
        "masked": false,
        "raw": false,
        "environment_scope": "*",
        "description": null
    },
    {
        "key": "TEST_VARIABLE_2",
        "variable_type": "env_var",
        "value": "TEST_2",
        "protected": false,
        "masked": false,
        "raw": false,
        "environment_scope": "*",
        "description": null
    }
]
```

## Show variable details

Get the details of a group's specific variable.

```plaintext
GET /groups/:id/variables/:key
```

| Attribute | Type           | Required | Description |
|-----------|----------------|----------|-------------|
| `id`      | integer/string | Yes      | The ID of a group or [URL-encoded path of the group](rest/index.md#namespaced-path-encoding) |
| `key`     | string         | Yes      | The `key` of a variable |

```shell
curl --header "PRIVATE-TOKEN: <your_access_token>" "https://gitlab.example.com/api/v4/groups/1/variables/TEST_VARIABLE_1"
```

```json
{
    "key": "TEST_VARIABLE_1",
    "variable_type": "env_var",
    "value": "TEST_1",
    "protected": false,
    "masked": false,
    "raw": false,
    "environment_scope": "*",
    "description": null
}
```

## Create variable

Create a new variable.

```plaintext
POST /groups/:id/variables
```

| Attribute                         | Type           | Required | Description |
|-----------------------------------|----------------|----------|-------------|
| `id`                              | integer/string | Yes      | The ID of a group or [URL-encoded path of the group](rest/index.md#namespaced-path-encoding) |
| `key`                             | string         | Yes      | The `key` of a variable; must have no more than 255 characters; only `A-Z`, `a-z`, `0-9`, and `_` are allowed |
| `value`                           | string         | Yes      | The `value` of a variable |
| `variable_type`                   | string         | No       | The type of a variable. Available types are: `env_var` (default) and `file` |
| `protected`                       | boolean        | No       | Whether the variable is protected |
| `masked`                          | boolean        | No       | Whether the variable is masked |
| `raw`                             | boolean        | No       | Whether the variable is treated as a raw string. Default: `false`. When `true`, variables in the value are not [expanded](../ci/variables/index.md#prevent-cicd-variable-expansion). |
| `environment_scope` **(PREMIUM)** | string         | No       | The [environment scope](../ci/environments/index.md#limit-the-environment-scope-of-a-cicd-variable) of a variable |
| `description`                     | string         | No       | The `description` of the variable. Default: `null` |

```shell
curl --request POST --header "PRIVATE-TOKEN: <your_access_token>" \
     "https://gitlab.example.com/api/v4/groups/1/variables" --form "key=NEW_VARIABLE" --form "value=new value"
```

```json
{
    "key": "NEW_VARIABLE",
    "value": "new value",
    "variable_type": "env_var",
    "protected": false,
    "masked": false,
    "raw": false,
    "environment_scope": "*",
    "description": null
}
```

## Update variable

Update a group's variable.

```plaintext
PUT /groups/:id/variables/:key
```

| Attribute                         | Type           | Required | Description |
|-----------------------------------|----------------|----------|-------------|
| `id`                              | integer/string | Yes      | The ID of a group or [URL-encoded path of the group](rest/index.md#namespaced-path-encoding) |
| `key`                             | string         | Yes      | The `key` of a variable |
| `value`                           | string         | Yes      | The `value` of a variable |
| `variable_type`                   | string         | No       | The type of a variable. Available types are: `env_var` (default) and `file` |
| `protected`                       | boolean        | No       | Whether the variable is protected |
| `masked`                          | boolean        | No       | Whether the variable is masked |
| `raw`                             | boolean        | No       | Whether the variable is treated as a raw string. Default: `false`. When `true`, variables in the value are not [expanded](../ci/variables/index.md#prevent-cicd-variable-expansion). |
| `environment_scope` **(PREMIUM)** | string         | No       | The [environment scope](../ci/environments/index.md#limit-the-environment-scope-of-a-cicd-variable) of a variable |
| `description`                     | string         | No       | The description of the variable. Default: `null`. [Introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/409641) in GitLab 16.2. |

```shell
curl --request PUT --header "PRIVATE-TOKEN: <your_access_token>" \
     "https://gitlab.example.com/api/v4/groups/1/variables/NEW_VARIABLE" --form "value=updated value"
```

```json
{
    "key": "NEW_VARIABLE",
    "value": "updated value",
    "variable_type": "env_var",
    "protected": true,
    "masked": true,
    "raw": true,
    "environment_scope": "*",
    "description": null
}
```

## Remove variable

Remove a group's variable.

```plaintext
DELETE /groups/:id/variables/:key
```

| Attribute | Type           | Required | Description |
|-----------|----------------|----------|-------------|
| `id`      | integer/string | Yes      | The ID of a group or [URL-encoded path of the group](rest/index.md#namespaced-path-encoding)     |
| `key`     | string         | Yes      | The `key` of a variable |

```shell
curl --request DELETE --header "PRIVATE-TOKEN: <your_access_token>" \
     "https://gitlab.example.com/api/v4/groups/1/variables/VARIABLE_1"
```
