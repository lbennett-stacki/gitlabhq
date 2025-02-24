<script>
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { stripQuotes } from '~/lib/utils/text_utility';
import { OPTIONS_NONE_ANY } from '../constants';

export default {
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
  },
  props: {
    active: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      emojis: this.config.initialEmojis || [],
      loading: false,
    };
  },
  computed: {
    defaultEmojis() {
      return this.config.defaultEmojis || OPTIONS_NONE_ANY;
    },
  },
  methods: {
    getActiveEmoji(emojis, data) {
      return emojis.find((emoji) => emoji.name.toLowerCase() === stripQuotes(data).toLowerCase());
    },
    fetchEmojis(searchTerm) {
      this.loading = true;
      this.config
        .fetchEmojis(searchTerm)
        .then((response) => {
          this.emojis = Array.isArray(response) ? response : response.data;
        })
        .catch(() => {
          createAlert({ message: __('There was a problem fetching emojis.') });
        })
        .finally(() => {
          this.loading = false;
        });
    },
  },
};
</script>

<template>
  <base-token
    :active="active"
    :config="config"
    :value="value"
    :default-suggestions="defaultEmojis"
    :suggestions="emojis"
    :suggestions-loading="loading"
    :get-active-token-value="getActiveEmoji"
    value-identifier="name"
    v-bind="$attrs"
    @fetch-suggestions="fetchEmojis"
    v-on="$listeners"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      <gl-emoji v-if="activeTokenValue" :data-name="activeTokenValue.name" />
      <template v-else>{{ inputValue }}</template>
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="emoji in suggestions"
        :key="emoji.name"
        :value="emoji.name"
      >
        <div class="gl-display-flex">
          <gl-emoji class="gl-mr-3" :data-name="emoji.name" />
          {{ emoji.name }}
        </div>
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
