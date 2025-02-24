import { GlCollapsibleListbox } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import Vuex from 'vuex';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BoardAddNewColumn from '~/boards/components/board_add_new_column.vue';
import BoardAddNewColumnForm from '~/boards/components/board_add_new_column_form.vue';
import defaultState from '~/boards/stores/state';
import createBoardListMutation from 'ee_else_ce/boards/graphql/board_list_create.mutation.graphql';
import boardLabelsQuery from '~/boards/graphql/board_labels.query.graphql';
import {
  mockLabelList,
  createBoardListResponse,
  labelsQueryResponse,
  boardListsQueryResponse,
} from '../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

describe('BoardAddNewColumn', () => {
  let wrapper;

  const createBoardListQueryHandler = jest.fn().mockResolvedValue(createBoardListResponse);
  const labelsQueryHandler = jest.fn().mockResolvedValue(labelsQueryResponse);
  const mockApollo = createMockApollo([
    [boardLabelsQuery, labelsQueryHandler],
    [createBoardListMutation, createBoardListQueryHandler],
  ]);

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findAddNewColumnForm = () => wrapper.findComponent(BoardAddNewColumnForm);
  const selectLabel = (id) => {
    findDropdown().vm.$emit('select', id);
  };

  const createStore = ({ actions = {}, getters = {}, state = {} } = {}) => {
    return new Vuex.Store({
      state: {
        ...defaultState,
        ...state,
      },
      actions,
      getters,
    });
  };

  const mountComponent = ({
    selectedId,
    labels = [],
    getListByLabelId = jest.fn(),
    actions = {},
    provide = {},
    lists = {},
  } = {}) => {
    wrapper = shallowMountExtended(BoardAddNewColumn, {
      apolloProvider: mockApollo,
      propsData: {
        listQueryVariables: {
          isGroup: false,
          isProject: true,
          fullPath: 'gitlab-org/gitlab',
          boardId: 'gid://gitlab/Board/1',
          filters: {},
        },
        boardId: 'gid://gitlab/Board/1',
        lists,
      },
      data() {
        return {
          selectedId,
        };
      },
      store: createStore({
        actions: {
          fetchLabels: jest.fn(),
          ...actions,
        },
        getters: {
          getListByLabelId: () => getListByLabelId,
        },
        state: {
          labels,
          labelsLoading: false,
        },
      }),
      provide: {
        scopedLabelsAvailable: true,
        isEpicBoard: false,
        issuableType: 'issue',
        fullPath: 'gitlab-org/gitlab',
        boardType: 'project',
        isApolloBoard: false,
        ...provide,
      },
      stubs: {
        GlCollapsibleListbox,
      },
    });

    // trigger change event
    if (selectedId) {
      selectLabel(selectedId);
    }

    // Necessary for cache update
    mockApollo.clients.defaultClient.cache.readQuery = jest
      .fn()
      .mockReturnValue(boardListsQueryResponse.data);
    mockApollo.clients.defaultClient.cache.writeQuery = jest.fn();
  };

  describe('Add list button', () => {
    it('calls addList', async () => {
      const getListByLabelId = jest.fn().mockReturnValue(null);
      const highlightList = jest.fn();
      const createList = jest.fn();

      mountComponent({
        labels: [mockLabelList.label],
        selectedId: mockLabelList.label.id,
        getListByLabelId,
        actions: {
          createList,
          highlightList,
        },
      });

      findAddNewColumnForm().vm.$emit('add-list');

      await nextTick();

      expect(highlightList).not.toHaveBeenCalled();
      expect(createList).toHaveBeenCalledWith(expect.anything(), {
        labelId: mockLabelList.label.id,
      });
    });

    it('highlights existing list if trying to re-add', async () => {
      const getListByLabelId = jest.fn().mockReturnValue(mockLabelList);
      const highlightList = jest.fn();
      const createList = jest.fn();

      mountComponent({
        labels: [mockLabelList.label],
        selectedId: mockLabelList.label.id,
        getListByLabelId,
        actions: {
          createList,
          highlightList,
        },
      });

      findAddNewColumnForm().vm.$emit('add-list');

      await nextTick();

      expect(highlightList).toHaveBeenCalledWith(expect.anything(), mockLabelList.id);
      expect(createList).not.toHaveBeenCalled();
    });
  });

  describe('Apollo boards', () => {
    describe('when list is new', () => {
      beforeEach(() => {
        mountComponent({ selectedId: mockLabelList.label.id, provide: { isApolloBoard: true } });
      });

      it('fetches labels and adds list', async () => {
        findDropdown().vm.$emit('show');

        await nextTick();
        expect(labelsQueryHandler).toHaveBeenCalled();

        selectLabel(mockLabelList.label.id);

        findAddNewColumnForm().vm.$emit('add-list');

        await nextTick();

        expect(wrapper.emitted('highlight-list')).toBeUndefined();
        expect(createBoardListQueryHandler).toHaveBeenCalledWith({
          labelId: mockLabelList.label.id,
          boardId: 'gid://gitlab/Board/1',
        });
      });
    });

    describe('when list already exists in board', () => {
      beforeEach(() => {
        mountComponent({
          lists: {
            [mockLabelList.id]: mockLabelList,
          },
          selectedId: mockLabelList.label.id,
          provide: { isApolloBoard: true },
        });
      });

      it('highlights existing list if trying to re-add', async () => {
        findDropdown().vm.$emit('show');

        await nextTick();
        expect(labelsQueryHandler).toHaveBeenCalled();

        selectLabel(mockLabelList.label.id);

        findAddNewColumnForm().vm.$emit('add-list');

        await nextTick();

        expect(wrapper.emitted('highlight-list')).toEqual([[mockLabelList.id]]);
        expect(createBoardListQueryHandler).not.toHaveBeenCalledWith();
      });
    });
  });
});
