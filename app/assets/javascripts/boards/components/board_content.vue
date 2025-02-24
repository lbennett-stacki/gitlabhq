<script>
import { GlAlert } from '@gitlab/ui';
import { sortBy } from 'lodash';
import produce from 'immer';
import Draggable from 'vuedraggable';
import { mapState, mapActions } from 'vuex';
import BoardAddNewColumn from 'ee_else_ce/boards/components/board_add_new_column.vue';
import { defaultSortableOptions } from '~/sortable/constants';
import {
  DraggableItemTypes,
  flashAnimationDuration,
  listsQuery,
  updateListQueries,
} from 'ee_else_ce/boards/constants';
import { calculateNewPosition } from 'ee_else_ce/boards/boards_util';
import BoardColumn from './board_column.vue';

export default {
  draggableItemTypes: DraggableItemTypes,
  components: {
    BoardAddNewColumn,
    BoardColumn,
    BoardContentSidebar: () => import('~/boards/components/board_content_sidebar.vue'),
    EpicBoardContentSidebar: () =>
      import('ee_component/boards/components/epic_board_content_sidebar.vue'),
    EpicsSwimlanes: () => import('ee_component/boards/components/epics_swimlanes.vue'),
    GlAlert,
  },
  inject: [
    'boardType',
    'canAdminList',
    'isIssueBoard',
    'isEpicBoard',
    'disabled',
    'issuableType',
    'isApolloBoard',
  ],
  props: {
    boardId: {
      type: String,
      required: true,
    },
    filterParams: {
      type: Object,
      required: true,
    },
    isSwimlanesOn: {
      type: Boolean,
      required: true,
    },
    boardListsApollo: {
      type: Object,
      required: false,
      default: () => {},
    },
    apolloError: {
      type: String,
      required: false,
      default: null,
    },
    listQueryVariables: {
      type: Object,
      required: true,
    },
    addColumnFormVisible: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      boardHeight: null,
      highlightedLists: [],
    };
  },
  computed: {
    ...mapState(['boardLists', 'error']),
    boardListsById() {
      return this.isApolloBoard ? this.boardListsApollo : this.boardLists;
    },
    boardListsToUse() {
      const lists = this.isApolloBoard ? this.boardListsApollo : this.boardLists;
      return sortBy([...Object.values(lists)], 'position');
    },
    canDragColumns() {
      return this.canAdminList;
    },
    boardColumnWrapper() {
      return this.canDragColumns ? Draggable : 'div';
    },
    draggableOptions() {
      const options = {
        ...defaultSortableOptions,
        disabled: this.disabled,
        draggable: '.is-draggable',
        fallbackOnBody: false,
        group: 'boards-list',
        tag: 'div',
        value: this.boardListsToUse,
        delay: 100,
        delayOnTouchOnly: true,
        filter: 'input',
        preventOnFilter: false,
      };

      return this.canDragColumns ? options : {};
    },
    errorToDisplay() {
      return this.apolloError || this.error || null;
    },
  },
  methods: {
    ...mapActions(['moveList', 'unsetError']),
    afterFormEnters() {
      const el = this.canDragColumns ? this.$refs.list.$el : this.$refs.list;
      el.scrollTo({ left: el.scrollWidth, behavior: 'smooth' });
    },
    highlightList(listId) {
      this.highlightedLists.push(listId);

      setTimeout(() => {
        this.highlightedLists = this.highlightedLists.filter((id) => id !== listId);
      }, flashAnimationDuration);
    },
    updateListPosition({
      item: {
        dataset: { listId: movedListId, draggableItemType },
      },
      newIndex,
      to: { children },
    }) {
      if (!this.isApolloBoard) {
        this.moveList({
          item: {
            dataset: { listId: movedListId, draggableItemType },
          },
          newIndex,
          to: { children },
        });
        return;
      }

      if (draggableItemType !== DraggableItemTypes.list) {
        return;
      }

      const displacedListId = children[newIndex].dataset.listId;

      if (movedListId === displacedListId) {
        return;
      }
      const initialPosition = this.boardListsById[movedListId].position;
      const targetPosition = this.boardListsById[displacedListId].position;

      try {
        this.$apollo.mutate({
          mutation: updateListQueries[this.issuableType].mutation,
          variables: {
            listId: movedListId,
            position: targetPosition,
          },
          update: (store) => {
            const sourceData = store.readQuery({
              query: listsQuery[this.issuableType].query,
              variables: this.listQueryVariables,
            });
            const data = produce(sourceData, (draftData) => {
              // for current list, new position is already set by Apollo via automatic update
              const affectedNodes = draftData[this.boardType].board.lists.nodes.filter(
                (node) => node.id !== movedListId,
              );
              affectedNodes.forEach((node) => {
                // eslint-disable-next-line no-param-reassign
                node.position = calculateNewPosition(
                  node.position,
                  initialPosition,
                  targetPosition,
                );
              });
            });
            store.writeQuery({
              query: listsQuery[this.issuableType].query,
              variables: this.listQueryVariables,
              data,
            });
          },
          optimisticResponse: {
            updateBoardList: {
              __typename: 'UpdateBoardListPayload',
              errors: [],
              list: {
                ...this.boardListsApollo[movedListId],
                position: targetPosition,
              },
            },
          },
        });
      } catch {
        // handle error
      }
    },
  },
};
</script>

<template>
  <div
    v-cloak
    data-qa-selector="boards_list"
    class="gl-flex-grow-1 gl-display-flex gl-flex-direction-column gl-min-h-0"
  >
    <gl-alert v-if="errorToDisplay" variant="danger" :dismissible="true" @dismiss="unsetError">
      {{ errorToDisplay }}
    </gl-alert>
    <component
      :is="boardColumnWrapper"
      v-if="!isSwimlanesOn"
      ref="list"
      v-bind="draggableOptions"
      class="boards-list gl-w-full gl-py-5 gl-pr-3 gl-white-space-nowrap gl-overflow-x-auto"
      @end="updateListPosition"
    >
      <board-column
        v-for="(list, index) in boardListsToUse"
        :key="index"
        ref="board"
        :board-id="boardId"
        :list="list"
        :filters="filterParams"
        :highlighted-lists-apollo="highlightedLists"
        :data-draggable-item-type="$options.draggableItemTypes.list"
        :class="{ 'gl-display-none! gl-sm-display-inline-block!': addColumnFormVisible }"
        @setActiveList="$emit('setActiveList', $event)"
      />

      <transition name="slide" @after-enter="afterFormEnters">
        <board-add-new-column
          v-if="addColumnFormVisible"
          class="gl-xs-w-full!"
          :board-id="boardId"
          :list-query-variables="listQueryVariables"
          :lists="boardListsById"
          @setAddColumnFormVisibility="$emit('setAddColumnFormVisibility', $event)"
          @highlight-list="highlightList"
        />
      </transition>
    </component>

    <epics-swimlanes
      v-else-if="boardListsToUse.length"
      ref="swimlanes"
      :board-id="boardId"
      :lists="boardListsToUse"
      :can-admin-list="canAdminList"
      :filters="filterParams"
      :highlighted-lists="highlightedLists"
      @setActiveList="$emit('setActiveList', $event)"
      @move-list="updateListPosition"
    >
      <board-add-new-column
        v-if="addColumnFormVisible"
        class="gl-sticky gl-top-5"
        :filter-params="filterParams"
        :list-query-variables="listQueryVariables"
        :board-id="boardId"
        :lists="boardListsById"
        @setAddColumnFormVisibility="$emit('setAddColumnFormVisibility', $event)"
        @highlight-list="highlightList"
      />
    </epics-swimlanes>

    <board-content-sidebar v-if="isIssueBoard" data-testid="issue-boards-sidebar" />

    <epic-board-content-sidebar v-else-if="isEpicBoard" data-testid="epic-boards-sidebar" />
  </div>
</template>
