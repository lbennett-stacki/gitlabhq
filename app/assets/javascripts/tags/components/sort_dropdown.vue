<script>
import { GlCollapsibleListbox, GlSearchBoxByClick } from '@gitlab/ui';
import { mergeUrlParams, visitUrl, getParameterValues } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';

export default {
  i18n: {
    searchPlaceholder: s__('TagsPage|Filter by tag name'),
  },
  components: {
    GlCollapsibleListbox,
    GlSearchBoxByClick,
  },
  inject: ['sortOptions', 'filterTagsPath'],
  data() {
    return {
      selectedKey: 'updated_desc',
      searchTerm: '',
    };
  },
  computed: {
    selectedSortMethod() {
      return this.sortOptions[this.selectedKey];
    },
    sortOptionsListboxItems() {
      return Object.entries(this.sortOptions).map(([value, text]) => {
        return { value, text };
      });
    },
  },
  created() {
    const sortValue = getParameterValues('sort');
    const searchValue = getParameterValues('search');

    if (sortValue.length > 0) {
      [this.selectedKey] = sortValue;
    }

    if (searchValue.length > 0) {
      [this.searchTerm] = searchValue;
    }
  },
  methods: {
    visitUrlFromOption(sortKey) {
      this.selectedKey = sortKey;
      const urlParams = {};

      urlParams.search = this.searchTerm.length > 0 ? this.searchTerm : null;
      urlParams.sort = sortKey;

      const newUrl = mergeUrlParams(urlParams, this.filterTagsPath);
      visitUrl(newUrl);
    },
  },
};
</script>
<template>
  <div class="gl-display-flex gl-pr-3">
    <gl-search-box-by-click
      v-model="searchTerm"
      :placeholder="$options.i18n.searchPlaceholder"
      class="gl-pr-3"
      data-testid="tag-search"
      @submit="visitUrlFromOption(selectedKey)"
    />
    <gl-collapsible-listbox
      v-model="selectedKey"
      data-testid="tags-dropdown"
      :items="sortOptionsListboxItems"
      placement="right"
      :toggle-text="selectedSortMethod"
      @select="visitUrlFromOption"
    />
  </div>
</template>
