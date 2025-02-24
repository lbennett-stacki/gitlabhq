<script>
import { mapGetters } from 'vuex';
import { refreshCurrentPage, queryToObject } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import BoardContent from '~/boards/components/board_content.vue';
import BoardSettingsSidebar from '~/boards/components/board_settings_sidebar.vue';
import BoardTopBar from '~/boards/components/board_top_bar.vue';
import eventHub from '~/boards/eventhub';
import { listsQuery } from 'ee_else_ce/boards/constants';
import { formatBoardLists } from 'ee_else_ce/boards/boards_util';
import activeBoardItemQuery from 'ee_else_ce/boards/graphql/client/active_board_item.query.graphql';
import errorQuery from '../graphql/client/error.query.graphql';

export default {
  i18n: {
    fetchError: s__(
      'Boards|An error occurred while fetching the board lists. Please reload the page.',
    ),
  },
  components: {
    BoardContent,
    BoardSettingsSidebar,
    BoardTopBar,
  },
  inject: [
    'fullPath',
    'initialBoardId',
    'initialFilterParams',
    'isIssueBoard',
    'isGroupBoard',
    'issuableType',
    'boardType',
    'isApolloBoard',
  ],
  data() {
    return {
      activeListId: '',
      boardId: this.initialBoardId,
      filterParams: { ...this.initialFilterParams },
      addColumnFormVisible: false,
      isShowingEpicsSwimlanes: Boolean(queryToObject(window.location.search).group_by),
      apolloError: null,
      error: null,
    };
  },
  apollo: {
    activeBoardItem: {
      query: activeBoardItemQuery,
      variables() {
        return {
          isIssue: this.isIssueBoard,
        };
      },
      result({ data: { activeBoardItem } }) {
        if (activeBoardItem) {
          this.setActiveId('');
        }
      },
      skip() {
        return !this.isApolloBoard;
      },
    },
    boardListsApollo: {
      query() {
        return listsQuery[this.issuableType].query;
      },
      variables() {
        return this.listQueryVariables;
      },
      skip() {
        return !this.isApolloBoard;
      },
      update(data) {
        const { lists } = data[this.boardType].board;
        return formatBoardLists(lists);
      },
      error() {
        this.apolloError = this.$options.i18n.fetchError;
      },
    },
    error: {
      query: errorQuery,
      update: (data) => data.boardsAppError,
    },
  },

  computed: {
    ...mapGetters(['isSidebarOpen']),
    listQueryVariables() {
      if (this.filterParams.groupBy) delete this.filterParams.groupBy;
      return {
        ...(this.isIssueBoard && {
          isGroup: this.isGroupBoard,
          isProject: !this.isGroupBoard,
        }),
        fullPath: this.fullPath,
        boardId: this.boardId,
        filters: this.filterParams,
      };
    },
    isSwimlanesOn() {
      return (gon?.licensed_features?.swimlanes && this.isShowingEpicsSwimlanes) ?? false;
    },
    isAnySidebarOpen() {
      if (this.isApolloBoard) {
        return this.activeBoardItem?.id || this.activeListId;
      }
      return this.isSidebarOpen;
    },
    activeList() {
      return this.activeListId ? this.boardListsApollo[this.activeListId] : undefined;
    },
  },
  created() {
    window.addEventListener('popstate', refreshCurrentPage);
    eventHub.$on('updateBoard', this.refetchLists);
  },
  destroyed() {
    window.removeEventListener('popstate', refreshCurrentPage);
    eventHub.$off('updateBoard', this.refetchLists);
  },
  methods: {
    refetchLists() {
      this.$apollo.queries.boardListsApollo.refetch();
    },
    setActiveId(id) {
      this.activeListId = id;
    },
    switchBoard(id) {
      this.boardId = id;
      this.setActiveId('');
    },
    setFilters(filters) {
      const filterParams = { ...filters };
      if (filterParams.groupBy) delete filterParams.groupBy;
      this.filterParams = filterParams;
    },
  },
};
</script>

<template>
  <div class="boards-app gl-relative" :class="{ 'is-compact': isAnySidebarOpen }">
    <board-top-bar
      :board-id="boardId"
      :add-column-form-visible="addColumnFormVisible"
      :is-swimlanes-on="isSwimlanesOn"
      @switchBoard="switchBoard"
      @setFilters="setFilters"
      @setAddColumnFormVisibility="addColumnFormVisible = $event"
      @toggleSwimlanes="isShowingEpicsSwimlanes = $event"
    />
    <board-content
      v-if="!isApolloBoard || boardListsApollo"
      :board-id="boardId"
      :add-column-form-visible="addColumnFormVisible"
      :is-swimlanes-on="isSwimlanesOn"
      :filter-params="filterParams"
      :board-lists-apollo="boardListsApollo"
      :apollo-error="apolloError || error"
      :list-query-variables="listQueryVariables"
      @setActiveList="setActiveId"
      @setAddColumnFormVisibility="addColumnFormVisible = $event"
    />
    <board-settings-sidebar
      v-if="!isApolloBoard || activeList"
      :list="activeList"
      :list-id="activeListId"
      :board-id="boardId"
      :query-variables="listQueryVariables"
      @unsetActiveId="setActiveId('')"
    />
  </div>
</template>
