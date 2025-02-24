---
stage: Manage
group: Authentication and Authorization
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Custom Roles

Users can create custom roles and define those roles by assigning specific abilities. For example, a user could create an "Engineer" role with `read code` and `admin merge requests` abilities, but without abilities like `admin issues`.

In this context:

- "Ability" is an action a user can do.
- "Permission" defines the policy classes.

## Custom roles vs static roles

In GitLab 15.9 and earlier, GitLab only had [static roles](predefined_roles.md) as a permission system. In this system, there are a few predefined roles that are statically assigned to certain abilities. These static roles are not customizable by customers.

With custom roles, the customers can decide which abilities they want to assign to certain user groups. For example:

- In the static role system, reading of vulnerabilities is limited to a Developer role.
- In the custom role system, a customer can assign this ability to a new custom role based on the Reporter role.

## Technical overview

Individual custom roles are stored in the `member_roles` table (`MemberRole` model) and can be defined only for top-level groups. This table includes individual abilities and a `base_access_level` value. This value defines the minimum access level of:

- Users who can be assigned to the custom role.
- Every ability.

For example, the `read_vulnerability` ability has a minimum access level of `Reporter`. That means only member role records with `base_access_level = REPORTER` (20) or higher can have the `read_vulnerability` value set to `true`. Also, only users who have at least the Reporter role can be assigned that ability.

For now, custom role abilities are supported only at project level.

## How to implement a new ability for custom roles

Usually 2-3 merge requests should be created for a new ability. The rough guidance is following:

1. Pick a feature you want to add abilities to custom roles.
1. Refactor & consolidate abilities for the feature (1-2 merge requests depending on the feature complexity)
1. Implement a new ability (1 merge request)

### Refactoring abilities

#### Finding existing abilities checks

Abilities are often [checked in multiple locations](../permissions/authorizations.md#where-should-permissions-be-checked) for a single endpoint or web request. Therefore, it can be difficult to find the list of authorization checks that are run for a given endpoint.

To assist with this, you can locally set `GITLAB_DEBUG_POLICIES=true`.

This outputs information about which abilities are checked in the requests
made in any specs that you run. The output also includes the line of code where the
authorization check was made. Caller information is especially helpful in cases
where there is metaprogramming used because those cases are difficult to find by
grepping for ability name strings.

For example:

```shell
# example spec run

GITLAB_DEBUG_POLICIES=true bundle exec rspec spec/controllers/groups_controller_spec.rb:162

# permissions debug output when spec is run; if multiple policy checks are run they will all be in the debug output.

POLICY CHECK DEBUG -> policy: GlobalPolicy, ability: create_group, called_from: ["/gitlab/app/controllers/application_controller.rb:245:in `can?'", "/gitlab/app/controllers/groups_controller.rb:255:in `authorize_create_group!'"]
```

Use this setting to learn more about authorization checks while
refactoring. You should not keep this setting enabled for any specs on the default branch.

#### Understanding logic for individual abilities

References to an ability may appear in a `DeclarativePolicy` class many times
and depend on conditions and rules which reference other abilities. As a result,
it can be challenging to know exactly which conditions apply to a particular
ability.

`DeclarativePolicy` provides a `ability_map` for each policy class, which
pulls all rules for an ability into an array.

For example:

```ruby
> GroupPolicy.ability_map.map.select { |k,v| k == :read_group_member }
=> {:read_group_member=>[[:enable, #<Rule can?(:read_group)>], [:prevent, #<Rule ~can_read_group_member>]]}

> GroupPolicy.ability_map.map.select { |k,v| k == :read_group }
=> {:read_group=>
  [[:enable, #<Rule public_group>],
   [:enable, #<Rule logged_in_viewable>],
   [:enable, #<Rule guest>],
   [:enable, #<Rule admin>],
   [:enable, #<Rule has_projects>],
   [:enable, #<Rule read_package_registry_deploy_token>],
   [:enable, #<Rule write_package_registry_deploy_token>],
   [:prevent, #<Rule all?(~public_group, ~admin, user_banned_from_group)>],
   [:enable, #<Rule auditor>],
   [:prevent, #<Rule needs_new_sso_session>],
   [:prevent, #<Rule all?(ip_enforcement_prevents_access, ~owner, ~auditor)>]]}
```

`DeclarativePolicy` also provides a `debug` method that can be used to
understand the logic tree for a specific object and actor. The output is similar
to the list of rules from `ability_map`. But, `DeclarativePolicy` stops
evaluating rules after you `prevent` an ability, so it is possible that
not all conditions are called.

Example:

```ruby
policy = GroupPolicy.new(User.last,  Group.last)
policy.debug(:read_group)

- [0] enable when public_group ((@custom_guest_user1 : Group/139))
- [0] enable when logged_in_viewable ((@custom_guest_user1 : Group/139))
- [0] enable when admin ((@custom_guest_user1 : Group/139))
- [0] enable when auditor ((@custom_guest_user1 : Group/139))
- [14] prevent when all?(~public_group, ~admin, user_banned_from_group) ((@custom_guest_user1 : Group/139))
- [14] prevent when needs_new_sso_session ((@custom_guest_user1 : Group/139))
- [16] enable when guest ((@custom_guest_user1 : Group/139))
- [16] enable when has_projects ((@custom_guest_user1 : Group/139))
- [16] enable when read_package_registry_deploy_token ((@custom_guest_user1 : Group/139))
- [16] enable when write_package_registry_deploy_token ((@custom_guest_user1 : Group/139))
  [21] prevent when all?(ip_enforcement_prevents_access, ~owner, ~auditor) ((@custom_guest_user1 : Group/139))

=> #<DeclarativePolicy::Runner::State:0x000000015c665050
 @called_conditions=
  #<Set: {
   "/dp/condition/GroupPolicy/public_group/Group:139",
   "/dp/condition/GroupPolicy/logged_in_viewable/User:83,Group:139",
   "/dp/condition/BasePolicy/admin/User:83",
   "/dp/condition/BasePolicy/auditor/User:83",
   "/dp/condition/GroupPolicy/user_banned_from_group/User:83,Group:139",
   "/dp/condition/GroupPolicy/needs_new_sso_session/User:83,Group:139",
   "/dp/condition/GroupPolicy/guest/User:83,Group:139",
   "/dp/condition/GroupPolicy/has_projects/User:83,Group:139",
   "/dp/condition/GroupPolicy/read_package_registry_deploy_token/User:83,Group:139",
   "/dp/condition/GroupPolicy/write_package_registry_deploy_token/User:83,Group:139"}>,
 @enabled=false,
 @prevented=true>
```

#### Abilities consolidation

Every feature added to custom roles should have minimal abilities. For most features, having `read_*` and `admin_*` should be enough. You should consolidate all:

- View-related abilities under `read_*`. For example, viewing a list or detail.
- Object updates under `admin_*`. For example, updating an object, adding assignees or closing it that object. Usually, a role that enables `admin_` has to have also `read_` abilities enabled. This is defined in `requirement` option in the `ALL_CUSTOMIZABLE_PERMISSIONS` hash on `MemberRole` model.

There might be features that require additional abilities but try to minimalize those. You can always ask members of the Authentication and Authorization group for their opinion or help.

This is also where your work should begin. Take all the abilities for the feature you work on, and consolidate those abilities into `read_`, `admin_`, or additional abilities if necessary.

### Implement a new ability

To add a new ability to a custom role:

- Add a new column to `member_roles` table, for example in [this change in merge request 114734](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/114734/diffs#diff-content-5c53d6f1c29a272a87eecea3f62d017ab6635275).
- Add the ability to the  `MemberRole` model, `ALL_CUSTOMIZABLE_PERMISSIONS` hash, for example in [this change in merge request 121534](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/121534/diffs#ce5ec769500a53ce2b603467d9984fc2b33ca71d_8_8). There are following possible keys in the `ALL_CUSTOMIZABLE_PERMISSIONS` hash:

  - `description` - description of the ability.
  - `minimal_level` - minimal level a user has to have in order to be able to be assigned to the ability.
  - `requirement` - required ability for the ability defined in the hash, in case the requirement is `false`, the ability can not be `true`.

- Add the ability to the respective Policy for example in [this change in merge request 114734](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/114734/diffs#diff-content-edcbe28bdecbd848d4d9efdc5b5e9bddd2a7299e).
- Update the specs.

Examples of merge requests adding new abilities to custom roles:

- [Read code](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/106256)
- [Read vulnerability](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/114734)
- [Admin vulnerability](https://gitlab.com/gitlab-org/gitlab/-/merge_requests/121534) - this is the newest MR implementing a new custom role ability. Some changes from the previous MRs are not neccessary anymore (eg. change of the Preloader query or adding a method to `User` model).

You should make sure a new custom roles ability is under a feature flag.

### Consuming seats

If a new user with a role `Guest` is added to a member role that includes enablement of an ability that is **not** in the `CUSTOMIZABLE_PERMISSIONS_EXEMPT_FROM_CONSUMING_SEAT` array, a seat is consumed. We simply want to make sure we are charging Ultimate customers for guest users, who have "elevated" abilities. This only applies to billable users on SaaS (billable users that are counted towards namespace subscription). More details about this topic can be found in [this issue](https://gitlab.com/gitlab-org/gitlab/-/issues/390269).
