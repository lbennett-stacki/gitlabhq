<script>
import {
  GlBadge,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
  GlTooltip,
} from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { s__ } from '~/locale';
import { USER_MENU_TRACKING_DEFAULTS } from '../constants';

export default {
  i18n: {
    user: {
      busy: s__('UserProfile|Busy'),
    },
  },
  components: {
    GlBadge,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlTooltip,
  },
  directives: {
    SafeHtml,
  },
  props: {
    user: {
      required: true,
      type: Object,
    },
  },
  computed: {
    menuItem() {
      const item = {
        text: this.user.name,
      };
      if (this.user.has_link_to_profile) {
        item.href = this.user.link_to_profile;

        item.extraAttrs = {
          ...USER_MENU_TRACKING_DEFAULTS,
          'data-track-label': 'user_profile',
          'data-testid': 'user_profile_link',
        };
      }

      return item;
    },
  },
};
</script>

<template>
  <gl-disclosure-dropdown-group>
    <gl-disclosure-dropdown-item :item="menuItem">
      <template #list-item>
        <span class="gl-display-flex gl-flex-direction-column">
          <span>
            <span class="gl-font-weight-bold">
              {{ user.name }}
            </span>
            <gl-badge v-if="user.status.busy" size="sm" variant="warning">
              {{ $options.i18n.user.busy }}
            </gl-badge>
          </span>

          <span class="gl-text-gray-400">@{{ user.username }}</span>

          <span
            v-if="user.status.customized"
            ref="statusTooltipTarget"
            data-testid="user-menu-status"
            class="gl-display-flex gl-align-items-center gl-mt-2 gl-font-sm"
          >
            <gl-emoji :data-name="user.status.emoji" class="gl-mr-1" />
            <span v-safe-html="user.status.message_html" class="gl-text-truncate"></span>
            <gl-tooltip
              :target="() => $refs.statusTooltipTarget"
              boundary="viewport"
              placement="bottom"
            >
              <span v-safe-html="user.status.message_html"></span>
            </gl-tooltip>
          </span>
        </span>
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown-group>
</template>
