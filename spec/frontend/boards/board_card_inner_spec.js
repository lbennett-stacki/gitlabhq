import { GlLabel, GlLoadingIcon, GlTooltip } from '@gitlab/ui';
import { range } from 'lodash';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import Vuex from 'vuex';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import IssuableBlockedIcon from '~/vue_shared/components/issuable_blocked_icon/issuable_blocked_icon.vue';
import BoardCardInner from '~/boards/components/board_card_inner.vue';
import WorkItemTypeIcon from '~/work_items/components/work_item_type_icon.vue';
import eventHub from '~/boards/eventhub';
import defaultStore from '~/boards/stores';
import { TYPE_ISSUE } from '~/issues/constants';
import { updateHistory } from '~/lib/utils/url_utility';
import { mockLabelList, mockIssue, mockIssueFullPath } from './mock_data';

jest.mock('~/lib/utils/url_utility');
jest.mock('~/boards/eventhub');

Vue.use(Vuex);
Vue.use(VueApollo);

describe('Board card component', () => {
  const user = {
    id: 1,
    name: 'testing 123',
    username: 'test',
    avatarUrl: 'test_image',
  };

  const label1 = {
    id: 3,
    title: 'testing 123',
    color: '#000CFF',
    textColor: 'white',
    description: 'test',
  };

  let wrapper;
  let issue;
  let list;
  let store;

  const findIssuableBlockedIcon = () => wrapper.findComponent(IssuableBlockedIcon);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEpicCountablesTotalTooltip = () => wrapper.findComponent(GlTooltip);
  const findEpicCountables = () => wrapper.findByTestId('epic-countables');
  const findEpicCountablesBadgeIssues = () => wrapper.findByTestId('epic-countables-counts-issues');
  const findEpicCountablesBadgeWeight = () => wrapper.findByTestId('epic-countables-weight-issues');
  const findEpicBadgeProgress = () => wrapper.findByTestId('epic-progress');
  const findEpicCountablesTotalWeight = () => wrapper.findByTestId('epic-countables-total-weight');
  const findEpicProgressTooltip = () => wrapper.findByTestId('epic-progress-tooltip-content');
  const findHiddenIssueIcon = () => wrapper.findByTestId('hidden-icon');
  const findWorkItemIcon = () => wrapper.findComponent(WorkItemTypeIcon);

  const performSearchMock = jest.fn();

  const createStore = () => {
    store = new Vuex.Store({
      actions: {
        performSearch: performSearchMock,
      },
      state: {
        ...defaultStore.state,
        isShowingLabels: true,
      },
    });
  };

  const createWrapper = ({ props = {}, isEpicBoard = false, isGroupBoard = true } = {}) => {
    wrapper = mountExtended(BoardCardInner, {
      store,
      apolloProvider: createMockApollo(),
      propsData: {
        list,
        item: issue,
        index: 0,
        ...props,
      },
      stubs: {
        GlLoadingIcon: true,
        BoardCardMoveToPosition: true,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      provide: {
        rootPath: '/',
        scopedLabelsAvailable: false,
        isEpicBoard,
        issuableType: TYPE_ISSUE,
        isGroupBoard,
        isApolloBoard: false,
      },
    });
  };

  beforeEach(() => {
    list = mockLabelList;
    issue = {
      ...mockIssue,
      labels: [list.label],
      assignees: [],
      weight: 1,
    };

    createStore();
    createWrapper({ props: { item: issue, list } });
  });

  afterEach(() => {
    store = null;
  });

  it('renders issue title', () => {
    expect(wrapper.find('.board-card-title').text()).toContain(issue.title);
  });

  it('includes issue base in link', () => {
    expect(wrapper.find('.board-card-title a').attributes('href')).toContain('/test');
  });

  it('includes issue title on link', () => {
    expect(wrapper.find('.board-card-title a').attributes('title')).toBe(issue.title);
  });

  it('does not render confidential icon', () => {
    expect(wrapper.find('.confidential-icon').exists()).toBe(false);
  });

  it('does not render hidden issue icon', () => {
    expect(findHiddenIssueIcon().exists()).toBe(false);
  });

  it('does not render the work type icon by default', () => {
    expect(findWorkItemIcon().exists()).toBe(false);
  });

  it('renders the work type icon when props is passed', () => {
    createWrapper({ props: { item: issue, list, showWorkItemTypeIcon: true } });
    expect(findWorkItemIcon().exists()).toBe(true);
    expect(findWorkItemIcon().props('workItemType')).toBe(issue.type);
  });

  it('renders issue ID with #', () => {
    expect(wrapper.find('.board-card-number').text()).toContain(`#${issue.iid}`);
  });

  it('does not render assignee', () => {
    expect(wrapper.find('.board-card-assignee .avatar').exists()).toBe(false);
  });

  it('does not render loading icon', () => {
    expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(false);
  });

  it('does not render item reference path', () => {
    createStore();
    createWrapper({ isGroupBoard: false });

    expect(wrapper.find('.board-card-number').text()).not.toContain(mockIssueFullPath);
  });

  it('renders item reference path', () => {
    expect(wrapper.find('.board-card-number').text()).toContain(mockIssueFullPath);
  });

  describe('blocked', () => {
    it('renders blocked icon if issue is blocked', () => {
      createWrapper({
        props: {
          item: {
            ...issue,
            blocked: true,
          },
        },
      });

      expect(findIssuableBlockedIcon().exists()).toBe(true);
    });

    it('does not show blocked icon if issue is not blocked', () => {
      createWrapper({
        props: {
          item: {
            ...issue,
            blocked: false,
          },
        },
      });

      expect(findIssuableBlockedIcon().exists()).toBe(false);
    });
  });

  describe('confidential issue', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: {
            ...wrapper.props('item'),
            confidential: true,
          },
        },
      });
    });

    it('renders confidential icon', () => {
      expect(wrapper.find('.confidential-icon').exists()).toBe(true);
    });
  });

  describe('hidden issue', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: {
            ...wrapper.props('item'),
            hidden: true,
          },
        },
      });
    });

    it('renders hidden issue icon', () => {
      expect(findHiddenIssueIcon().exists()).toBe(true);
    });

    it('displays a tooltip which explains the meaning of the icon', () => {
      const tooltip = getBinding(findHiddenIssueIcon().element, 'gl-tooltip');

      expect(tooltip).toBeDefined();
      expect(findHiddenIssueIcon().attributes('title')).toBe(
        'This issue is hidden because its author has been banned',
      );
    });
  });

  describe('with assignee', () => {
    describe('with avatar', () => {
      beforeEach(() => {
        createWrapper({
          props: {
            item: {
              ...wrapper.props('item'),
              assignees: [user],
              updateData(newData) {
                Object.assign(this, newData);
              },
            },
          },
        });
      });

      it('renders assignee', () => {
        expect(wrapper.find('.board-card-assignee .gl-avatar').exists()).toBe(true);
      });

      it('sets title', () => {
        expect(wrapper.find('.js-assignee-tooltip').text()).toContain(`${user.name}`);
      });

      it('sets users path', () => {
        expect(wrapper.find('.board-card-assignee a').attributes('href')).toBe('/test');
      });

      it('renders avatar', () => {
        expect(wrapper.find('.board-card-assignee img').exists()).toBe(true);
      });

      it('renders the avatar using avatarUrl property', async () => {
        wrapper.props('item').updateData({
          ...wrapper.props('item'),
          assignees: [
            {
              id: '1',
              name: 'test',
              state: 'active',
              username: 'test_name',
              avatarUrl: 'test_image_from_avatar_url',
            },
          ],
        });

        await nextTick();

        expect(wrapper.find('.board-card-assignee img').attributes('src')).toBe(
          'test_image_from_avatar_url?width=24',
        );
      });
    });

    describe('with default avatar', () => {
      beforeEach(() => {
        global.gon.default_avatar_url = 'default_avatar';

        createWrapper({
          props: {
            item: {
              ...wrapper.props('item'),
              assignees: [
                {
                  id: 1,
                  name: 'testing 123',
                  username: 'test',
                },
              ],
            },
          },
        });
      });

      it('displays defaults avatar if users avatar is null', () => {
        expect(wrapper.find('.board-card-assignee img').exists()).toBe(true);
        expect(wrapper.find('.board-card-assignee img').attributes('src')).toBe(
          'default_avatar?width=24',
        );
      });
    });
  });

  describe('multiple assignees', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: {
            ...wrapper.props('item'),
            assignees: [
              {
                id: 2,
                name: 'user2',
                username: 'user2',
                avatarUrl: 'test_image',
              },
              {
                id: 3,
                name: 'user3',
                username: 'user3',
                avatarUrl: 'test_image',
              },
              {
                id: 4,
                name: 'user4',
                username: 'user4',
                avatarUrl: 'test_image',
              },
            ],
          },
        },
      });
    });

    it('renders all three assignees', () => {
      expect(wrapper.findAll('.board-card-assignee .gl-avatar').length).toEqual(3);
    });

    describe('more than three assignees', () => {
      beforeEach(() => {
        const { assignees } = wrapper.props('item');
        assignees.push({
          id: 5,
          name: 'user5',
          username: 'user5',
          avatarUrl: 'test_image',
        });

        createWrapper({
          props: {
            item: {
              ...wrapper.props('item'),
              assignees,
            },
          },
        });
      });

      it('renders more avatar counter', () => {
        expect(wrapper.find('.board-card-assignee .avatar-counter').text().trim()).toEqual('+2');
      });

      it('renders two assignees', () => {
        expect(wrapper.findAll('.board-card-assignee .gl-avatar').length).toEqual(2);
      });

      it('renders 99+ avatar counter', async () => {
        const assignees = [
          ...wrapper.props('item').assignees,
          ...range(5, 103).map((i) => ({
            id: i,
            name: 'name',
            username: 'username',
            avatarUrl: 'test_image',
          })),
        ];
        createWrapper({
          props: {
            item: {
              ...wrapper.props('item'),
              assignees,
            },
          },
        });

        await nextTick();

        expect(wrapper.find('.board-card-assignee .avatar-counter').text().trim()).toEqual('99+');
      });
    });
  });

  describe('labels', () => {
    beforeEach(() => {
      createWrapper({ props: { item: { ...issue, labels: [list.label, label1] } } });
    });

    it('does not render list label but renders all other labels', () => {
      expect(wrapper.findAllComponents(GlLabel).length).toBe(1);
      const label = wrapper.findComponent(GlLabel);
      expect(label.props('title')).toEqual(label1.title);
      expect(label.props('description')).toEqual(label1.description);
      expect(label.props('backgroundColor')).toEqual(label1.color);
    });

    it('does not render label if label does not have an ID', async () => {
      createWrapper({ props: { item: { ...issue, labels: [label1, { title: 'closed' }] } } });

      await nextTick();

      expect(wrapper.findAllComponents(GlLabel).length).toBe(1);
      expect(wrapper.text()).not.toContain('closed');
    });
  });

  describe('filterByLabel method', () => {
    beforeEach(() => {
      createWrapper({
        props: {
          item: {
            ...issue,
            labels: [label1],
          },
          updateFilters: true,
        },
      });
    });

    describe('when selected label is not in the filter', () => {
      beforeEach(() => {
        setWindowLocation('?');
        wrapper.findComponent(GlLabel).vm.$emit('click', label1);
      });

      it('calls updateHistory', () => {
        expect(updateHistory).toHaveBeenCalledTimes(1);
      });

      it('dispatches performSearch vuex action', () => {
        expect(performSearchMock).toHaveBeenCalledTimes(1);
      });

      it('emits updateTokens event', () => {
        expect(eventHub.$emit).toHaveBeenCalledTimes(1);
        expect(eventHub.$emit).toHaveBeenCalledWith('updateTokens');
      });
    });

    describe('when selected label is already in the filter', () => {
      beforeEach(() => {
        setWindowLocation('?label_name[]=testing%20123');
        wrapper.findComponent(GlLabel).vm.$emit('click', label1);
      });

      it('does not call updateHistory', () => {
        expect(updateHistory).not.toHaveBeenCalled();
      });

      it('does not dispatch performSearch vuex action', () => {
        expect(performSearchMock).not.toHaveBeenCalled();
      });

      it('does not emit updateTokens event', () => {
        expect(eventHub.$emit).not.toHaveBeenCalled();
      });
    });
  });

  describe('loading', () => {
    it('renders loading icon', () => {
      createWrapper({
        props: {
          item: {
            ...issue,
            isLoading: true,
          },
        },
      });

      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('is an epic board', () => {
    const descendantCounts = {
      closedEpics: 0,
      closedIssues: 0,
      openedEpics: 0,
      openedIssues: 0,
    };

    const descendantWeightSum = {
      closedIssues: 0,
      openedIssues: 0,
    };

    beforeEach(() => {
      createStore();
    });

    it('should render if the item has issues', () => {
      createWrapper({
        props: {
          item: {
            ...issue,
            descendantCounts,
            descendantWeightSum,
            hasIssues: true,
          },
        },
        isEpicBoard: true,
      });

      expect(findEpicCountables().exists()).toBe(true);
    });

    it('should not render if the item does not have issues', () => {
      createWrapper({
        item: {
          ...issue,
          descendantCounts,
          descendantWeightSum,
          hasIssues: false,
        },
      });

      expect(findEpicCountablesBadgeIssues().exists()).toBe(false);
    });

    it('shows render item countBadge, weights, and progress correctly', () => {
      createWrapper({
        props: {
          item: {
            ...issue,
            descendantCounts: {
              ...descendantCounts,
              openedIssues: 1,
            },
            descendantWeightSum: {
              closedIssues: 10,
              openedIssues: 5,
            },
            hasIssues: true,
          },
        },
        isEpicBoard: true,
      });

      expect(findEpicCountablesBadgeIssues().text()).toBe('1');
      expect(findEpicCountablesBadgeWeight().text()).toBe('15');
      expect(findEpicBadgeProgress().text()).toBe('67%');
    });

    it('does not render progress when weight is zero', () => {
      createWrapper({
        props: {
          item: {
            ...issue,
            descendantCounts: {
              ...descendantCounts,
              openedIssues: 1,
            },
            descendantWeightSum,
            hasIssues: true,
          },
        },
        isEpicBoard: true,
      });

      expect(findEpicBadgeProgress().exists()).toBe(false);
    });

    it('renders the tooltip with the correct data', () => {
      createWrapper({
        props: {
          item: {
            ...issue,
            descendantCounts,
            descendantWeightSum: {
              closedIssues: 10,
              openedIssues: 5,
            },
            hasIssues: true,
          },
        },
        isEpicBoard: true,
      });

      const tooltip = findEpicCountablesTotalTooltip();
      expect(tooltip).toBeDefined();

      expect(findEpicCountablesTotalWeight().text()).toBe('15');
      expect(findEpicProgressTooltip().text()).toBe('10 of 15 weight completed');
    });
  });
});
