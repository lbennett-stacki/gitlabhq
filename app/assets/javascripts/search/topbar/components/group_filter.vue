<script>
import { isEmpty } from 'lodash';
import { mapState, mapActions, mapGetters } from 'vuex';
import { visitUrl, setUrlParams } from '~/lib/utils/url_utility';
import { ANY_OPTION, GROUP_DATA, PROJECT_DATA } from '../constants';
import SearchableDropdown from './searchable_dropdown.vue';

export default {
  name: 'GroupFilter',
  components: {
    SearchableDropdown,
  },
  props: {
    initialData: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    ...mapState(['query', 'groups', 'fetchingGroups']),
    ...mapGetters(['frequentGroups', 'currentScope']),
    selectedGroup() {
      return isEmpty(this.initialData) ? ANY_OPTION : this.initialData;
    },
  },
  created() {
    // This tracks groups searched via the top nav search bar
    if (this.query.nav_source === 'navbar' && this.initialData?.id) {
      this.setFrequentGroup(this.initialData);
    }
  },
  methods: {
    ...mapActions(['fetchGroups', 'setFrequentGroup', 'loadFrequentGroups']),
    handleGroupChange(group) {
      // If group.id is null we are clearing the filter and don't need to store that in LS.
      if (group.id) {
        this.setFrequentGroup(group);
      }

      visitUrl(
        setUrlParams({
          [GROUP_DATA.queryParam]: group.id,
          [PROJECT_DATA.queryParam]: null,
          nav_source: null,
          scope: this.currentScope,
        }),
      );
    },
  },
  GROUP_DATA,
};
</script>

<template>
  <searchable-dropdown
    data-testid="group-filter"
    :header-text="$options.GROUP_DATA.headerText"
    :name="$options.GROUP_DATA.name"
    :full-name="$options.GROUP_DATA.fullName"
    :loading="fetchingGroups"
    :selected-item="selectedGroup"
    :items="groups"
    :frequent-items="frequentGroups"
    @first-open="loadFrequentGroups"
    @search="fetchGroups"
    @change="handleGroupChange"
  />
</template>
