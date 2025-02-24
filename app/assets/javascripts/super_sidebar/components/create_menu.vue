<script>
import {
  GlDisclosureDropdown,
  GlTooltip,
  GlDisclosureDropdownGroup,
  GlDisclosureDropdownItem,
} from '@gitlab/ui';
import InviteMembersTrigger from '~/invite_members/components/invite_members_trigger.vue';
import { __ } from '~/locale';
import {
  TOP_NAV_INVITE_MEMBERS_COMPONENT,
  TRIGGER_ELEMENT_DISCLOSURE_DROPDOWN,
} from '~/invite_members/constants';
import { DROPDOWN_Y_OFFSET, IMPERSONATING_OFFSET } from '../constants';

// Left offset required for the dropdown to be aligned with the super sidebar
const DROPDOWN_X_OFFSET_BASE = -147;
const DROPDOWN_X_OFFSET_IMPERSONATING = DROPDOWN_X_OFFSET_BASE + IMPERSONATING_OFFSET;

export default {
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownGroup,
    GlDisclosureDropdownItem,
    GlTooltip,
    InviteMembersTrigger,
  },
  i18n: {
    createNew: __('Create new...'),
  },
  inject: ['isImpersonating'],
  props: {
    groups: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      dropdownOpen: false,
    };
  },
  computed: {
    dropdownOffset() {
      return {
        mainAxis: DROPDOWN_Y_OFFSET,
        crossAxis: this.isImpersonating ? DROPDOWN_X_OFFSET_IMPERSONATING : DROPDOWN_X_OFFSET_BASE,
      };
    },
  },
  methods: {
    isInvitedMembers(groupItem) {
      return groupItem.component === TOP_NAV_INVITE_MEMBERS_COMPONENT;
    },
  },
  toggleId: 'create-menu-toggle',
  TRIGGER_ELEMENT_DISCLOSURE_DROPDOWN,
};
</script>

<template>
  <div>
    <gl-disclosure-dropdown
      category="tertiary"
      icon="plus"
      no-caret
      text-sr-only
      :toggle-text="$options.i18n.createNew"
      :toggle-id="$options.toggleId"
      :dropdown-offset="dropdownOffset"
      data-qa-selector="new_menu_toggle"
      data-testid="new-menu-toggle"
      @shown="dropdownOpen = true"
      @hidden="dropdownOpen = false"
    >
      <gl-disclosure-dropdown-group
        v-for="(group, index) in groups"
        :key="group.name"
        :bordered="index !== 0"
        :group="group"
      >
        <template v-for="groupItem in group.items">
          <invite-members-trigger
            v-if="isInvitedMembers(groupItem)"
            :key="`${groupItem.text}-trigger`"
            trigger-source="top-nav"
            :trigger-element="$options.TRIGGER_ELEMENT_DISCLOSURE_DROPDOWN"
          />
          <gl-disclosure-dropdown-item v-else :key="groupItem.text" :item="groupItem" />
        </template>
      </gl-disclosure-dropdown-group>
    </gl-disclosure-dropdown>
    <gl-tooltip
      v-if="!dropdownOpen"
      :target="`#${$options.toggleId}`"
      placement="bottom"
      container="#super-sidebar"
    >
      {{ $options.i18n.createNew }}
    </gl-tooltip>
  </div>
</template>
