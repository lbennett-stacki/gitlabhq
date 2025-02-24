import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { GlLoadingIcon, GlToast } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import FailedJobsList from '~/pipelines/components/pipelines_list/failure_widget/failed_jobs_list.vue';
import FailedJobDetails from '~/pipelines/components/pipelines_list/failure_widget/failed_job_details.vue';
import * as utils from '~/pipelines/components/pipelines_list/failure_widget/utils';
import getPipelineFailedJobs from '~/pipelines/graphql/queries/get_pipeline_failed_jobs.query.graphql';
import { failedJobsMock, failedJobsMock2, failedJobsMockEmpty, activeFailedJobsMock } from './mock';

Vue.use(VueApollo);
Vue.use(GlToast);

jest.mock('~/alert');

describe('FailedJobsList component', () => {
  let wrapper;
  let mockFailedJobsResponse;
  const showToast = jest.fn();

  const defaultProps = {
    graphqlResourceEtag: 'api/graphql',
    isPipelineActive: false,
    pipelineIid: 1,
    pipelinePath: '/pipelines/1',
  };

  const defaultProvide = {
    fullPath: 'namespace/project/',
    graphqlPath: 'api/graphql',
  };

  const createComponent = ({ props = {}, provide } = {}) => {
    const handlers = [[getPipelineFailedJobs, mockFailedJobsResponse]];
    const mockApollo = createMockApollo(handlers);

    wrapper = shallowMountExtended(FailedJobsList, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      apolloProvider: mockApollo,
      mocks: {
        $toast: {
          show: showToast,
        },
      },
    });
  };

  const findAllHeaders = () => wrapper.findAllByTestId('header');
  const findFailedJobRows = () => wrapper.findAllComponents(FailedJobDetails);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findNoFailedJobsText = () => wrapper.findByText('No failed jobs in this pipeline 🎉');

  beforeEach(() => {
    mockFailedJobsResponse = jest.fn();
  });

  describe('when loading failed jobs', () => {
    beforeEach(() => {
      mockFailedJobsResponse.mockResolvedValue(failedJobsMock);
      createComponent();
    });

    it('shows a loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when failed jobs have loaded', () => {
    beforeEach(async () => {
      mockFailedJobsResponse.mockResolvedValue(failedJobsMock);
      jest.spyOn(utils, 'sortJobsByStatus');

      createComponent();

      await waitForPromises();
    });

    it('does not renders a loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders table column', () => {
      expect(findAllHeaders()).toHaveLength(4);
    });

    it('shows the list of failed jobs', () => {
      expect(findFailedJobRows()).toHaveLength(
        failedJobsMock.data.project.pipeline.jobs.nodes.length,
      );
    });

    it('does not renders the empty state', () => {
      expect(findNoFailedJobsText().exists()).toBe(false);
    });

    it('calls sortJobsByStatus', () => {
      expect(utils.sortJobsByStatus).toHaveBeenCalledWith(
        failedJobsMock.data.project.pipeline.jobs.nodes,
      );
    });
  });

  describe('when there are no failed jobs', () => {
    beforeEach(async () => {
      mockFailedJobsResponse.mockResolvedValue(failedJobsMockEmpty);
      jest.spyOn(utils, 'sortJobsByStatus');

      createComponent();

      await waitForPromises();
    });

    it('renders the empty state', () => {
      expect(findNoFailedJobsText().exists()).toBe(true);
    });
  });

  describe('polling', () => {
    it.each`
      isGraphqlActive | text
      ${true}         | ${'polls'}
      ${false}        | ${'does not poll'}
    `(`$text when isGraphqlActive: $isGraphqlActive`, async ({ isGraphqlActive }) => {
      const defaultCount = 2;
      const newCount = 1;

      const expectedCount = isGraphqlActive ? newCount : defaultCount;
      const expectedCallCount = isGraphqlActive ? 2 : 1;
      const mockResponse = isGraphqlActive ? activeFailedJobsMock : failedJobsMock;

      // Second result is to simulate polling with a different response
      mockFailedJobsResponse.mockResolvedValueOnce(mockResponse);
      mockFailedJobsResponse.mockResolvedValueOnce(failedJobsMock2);

      createComponent();
      await waitForPromises();

      // Initially, we get the first response which is always the default
      expect(mockFailedJobsResponse).toHaveBeenCalledTimes(1);
      expect(findFailedJobRows()).toHaveLength(defaultCount);

      jest.advanceTimersByTime(10000);
      await waitForPromises();

      expect(mockFailedJobsResponse).toHaveBeenCalledTimes(expectedCallCount);
      expect(findFailedJobRows()).toHaveLength(expectedCount);
    });
  });

  describe('when a REST action occurs', () => {
    beforeEach(() => {
      // Second result is to simulate polling with a different response
      mockFailedJobsResponse.mockResolvedValueOnce(failedJobsMock);
      mockFailedJobsResponse.mockResolvedValueOnce(failedJobsMock2);
    });

    it.each([true, false])('triggers a refetch of the jobs count', async (isPipelineActive) => {
      const defaultCount = 2;
      const newCount = 1;

      createComponent({ props: { isPipelineActive } });
      await waitForPromises();

      // Initially, we get the first response which is always the default
      expect(mockFailedJobsResponse).toHaveBeenCalledTimes(1);
      expect(findFailedJobRows()).toHaveLength(defaultCount);

      wrapper.setProps({ isPipelineActive: !isPipelineActive });
      await waitForPromises();

      expect(mockFailedJobsResponse).toHaveBeenCalledTimes(2);
      expect(findFailedJobRows()).toHaveLength(newCount);
    });
  });

  describe('when an error occurs loading jobs', () => {
    const errorMessage = "We couldn't fetch jobs for you because you are not qualified";

    beforeEach(async () => {
      mockFailedJobsResponse.mockRejectedValue({ message: errorMessage });

      createComponent();

      await waitForPromises();
    });
    it('does not renders a loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('calls create Alert with the error message and danger variant', () => {
      expect(createAlert).toHaveBeenCalledWith({ message: errorMessage, variant: 'danger' });
    });
  });

  describe('when `refetch-jobs` job is fired from the widget', () => {
    beforeEach(async () => {
      mockFailedJobsResponse.mockResolvedValueOnce(failedJobsMock);
      mockFailedJobsResponse.mockResolvedValueOnce(failedJobsMock2);

      createComponent();

      await waitForPromises();
    });

    it('refetches all failed jobs', async () => {
      expect(findFailedJobRows()).not.toHaveLength(
        failedJobsMock2.data.project.pipeline.jobs.nodes.length,
      );

      await findFailedJobRows().at(0).vm.$emit('job-retried', 'job-name');
      await waitForPromises();

      expect(findFailedJobRows()).toHaveLength(
        failedJobsMock2.data.project.pipeline.jobs.nodes.length,
      );
    });

    it('shows a toast message', async () => {
      await findFailedJobRows().at(0).vm.$emit('job-retried', 'job-name');
      await waitForPromises();

      expect(showToast).toHaveBeenCalledWith('job-name job is being retried');
    });
  });
});
