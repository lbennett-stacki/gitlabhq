<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { visitUrl } from '~/lib/utils/url_utility';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getEnvironment from '../graphql/queries/environment.query.graphql';
import getEnvironmentWithNamespace from '../graphql/queries/environment_with_namespace.graphql';
import updateEnvironment from '../graphql/mutations/update_environment.mutation.graphql';
import EnvironmentForm from './environment_form.vue';

export default {
  components: {
    GlLoadingIcon,
    EnvironmentForm,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['projectEnvironmentsPath', 'projectPath', 'environmentName'],
  apollo: {
    environment: {
      query() {
        return this.glFeatures?.kubernetesNamespaceForEnvironment
          ? getEnvironmentWithNamespace
          : getEnvironment;
      },
      variables() {
        return {
          environmentName: this.environmentName,
          projectFullPath: this.projectPath,
        };
      },
      update(data) {
        const result = data?.project?.environment || {};
        this.formEnvironment = { ...result, clusterAgentId: result?.clusterAgent?.id };
      },
    },
  },
  data() {
    return {
      loading: false,
      formEnvironment: null,
    };
  },
  computed: {
    isQueryLoading() {
      return this.$apollo.queries.environment.loading;
    },
  },
  methods: {
    onChange(environment) {
      this.formEnvironment = environment;
    },
    async onSubmit() {
      this.loading = true;
      try {
        const { data } = await this.$apollo.mutate({
          mutation: updateEnvironment,
          variables: {
            input: {
              id: this.formEnvironment.id,
              externalUrl: this.formEnvironment.externalUrl,
              clusterAgentId: this.formEnvironment.clusterAgentId,
              kubernetesNamespace: this.formEnvironment.kubernetesNamespace,
            },
          },
        });

        const { errors } = data.environmentUpdate;

        if (errors.length > 0) {
          throw new Error(errors[0]?.message ?? errors[0]);
        }

        const { path } = data.environmentUpdate.environment;

        if (path) {
          visitUrl(path);
        }
      } catch (error) {
        const { message } = error;
        createAlert({ message });
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>
<template>
  <gl-loading-icon v-if="isQueryLoading" class="gl-mt-5" />
  <environment-form
    v-else-if="formEnvironment"
    :cancel-path="projectEnvironmentsPath"
    :environment="formEnvironment"
    :title="__('Edit environment')"
    :loading="loading"
    @change="onChange"
    @submit="onSubmit"
  />
</template>
