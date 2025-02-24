import { cloneDeep } from 'lodash';
import { GROUPS_LOCAL_STORAGE_KEY, PROJECTS_LOCAL_STORAGE_KEY } from '~/search/store/constants';
import * as getters from '~/search/store/getters';
import createState from '~/search/store/state';
import { useMockLocationHelper } from 'helpers/mock_window_location_helper';
import {
  MOCK_QUERY,
  MOCK_GROUPS,
  MOCK_PROJECTS,
  MOCK_AGGREGATIONS,
  MOCK_LANGUAGE_AGGREGATIONS_BUCKETS,
  TEST_FILTER_DATA,
  MOCK_NAVIGATION,
  MOCK_NAVIGATION_ITEMS,
  MOCK_LABEL_AGGREGATIONS,
  SMALL_MOCK_AGGREGATIONS,
  MOCK_LABEL_SEARCH_RESULT,
  MOCK_FILTERED_APPLIED_SELECTED_LABELS,
  MOCK_FILTERED_UNSELECTED_LABELS,
  MOCK_FILTERED_UNAPPLIED_SELECTED_LABELS,
} from '../mock_data';

describe('Global Search Store Getters', () => {
  let state;
  const defaultState = createState({ query: MOCK_QUERY });

  defaultState.aggregations = MOCK_LABEL_AGGREGATIONS;
  defaultState.aggregations.data.push(SMALL_MOCK_AGGREGATIONS[0]);

  beforeEach(() => {
    state = cloneDeep(defaultState);

    useMockLocationHelper();
  });

  describe('frequentGroups', () => {
    it('returns the correct data', () => {
      state.frequentItems[GROUPS_LOCAL_STORAGE_KEY] = MOCK_GROUPS;
      expect(getters.frequentGroups(state)).toStrictEqual(MOCK_GROUPS);
    });
  });

  describe('frequentProjects', () => {
    it('returns the correct data', () => {
      state.frequentItems[PROJECTS_LOCAL_STORAGE_KEY] = MOCK_PROJECTS;
      expect(getters.frequentProjects(state)).toStrictEqual(MOCK_PROJECTS);
    });
  });

  describe('languageAggregationBuckets', () => {
    it('returns the correct data', () => {
      state.aggregations.data = MOCK_AGGREGATIONS;
      expect(getters.languageAggregationBuckets(state)).toStrictEqual(
        MOCK_LANGUAGE_AGGREGATIONS_BUCKETS,
      );
    });
  });

  describe('queryLanguageFilters', () => {
    it('returns the correct data', () => {
      state.query.language = Object.keys(TEST_FILTER_DATA.filters);
      expect(getters.queryLanguageFilters(state)).toStrictEqual(state.query.language);
    });
  });

  describe('currentScope', () => {
    it('returns the correct scope name', () => {
      state.navigation = MOCK_NAVIGATION;
      expect(getters.currentScope(state)).toBe('issues');
    });
  });

  describe('currentUrlQueryHasLanguageFilters', () => {
    it.each`
      description             | lang                        | result
      ${'has valid language'} | ${{ language: ['a', 'b'] }} | ${true}
      ${'has empty lang'}     | ${{ language: [] }}         | ${false}
      ${'has no lang'}        | ${{}}                       | ${false}
    `('$description', ({ lang, result }) => {
      state.urlQuery = lang;
      expect(getters.currentUrlQueryHasLanguageFilters(state)).toBe(result);
    });
  });

  describe('navigationItems', () => {
    it('returns the re-mapped navigation data', () => {
      state.navigation = MOCK_NAVIGATION;
      expect(getters.navigationItems(state)).toStrictEqual(MOCK_NAVIGATION_ITEMS);
    });
  });

  describe('labelAggregationBuckets', () => {
    it('strips labels buckets from all aggregations', () => {
      expect(getters.labelAggregationBuckets(state)).toStrictEqual(
        MOCK_LABEL_AGGREGATIONS.data[0].buckets,
      );
    });
  });

  describe('filteredLabels', () => {
    it('gets all labels if no string is set', () => {
      state.searchLabelString = '';
      expect(getters.filteredLabels(state)).toStrictEqual(MOCK_LABEL_AGGREGATIONS.data[0].buckets);
    });

    it('get correct labels if string is set', () => {
      state.searchLabelString = 'SYNC';
      expect(getters.filteredLabels(state)).toStrictEqual([MOCK_LABEL_SEARCH_RESULT]);
    });
  });

  describe('filteredAppliedSelectedLabels', () => {
    it('returns all labels that are selected (part of URL)', () => {
      expect(getters.filteredAppliedSelectedLabels(state)).toStrictEqual(
        MOCK_FILTERED_APPLIED_SELECTED_LABELS,
      );
    });

    it('returns labels that are selected (part of URL) and result of search', () => {
      state.searchLabelString = 'SYNC';
      expect(getters.filteredAppliedSelectedLabels(state)).toStrictEqual([
        MOCK_FILTERED_APPLIED_SELECTED_LABELS[1],
      ]);
    });
  });

  describe('appliedSelectedLabels', () => {
    it('returns all labels that are selected (part of URL) no search', () => {
      state.searchLabelString = 'SYNC';
      expect(getters.appliedSelectedLabels(state)).toStrictEqual(
        MOCK_FILTERED_APPLIED_SELECTED_LABELS,
      );
    });
  });

  describe('filteredUnappliedSelectedLabels', () => {
    beforeEach(() => {
      state.query.labels = ['6', '73'];
    });

    it('returns all labels that are selected (part of URL) no search', () => {
      expect(getters.filteredUnappliedSelectedLabels(state)).toStrictEqual(
        MOCK_FILTERED_UNAPPLIED_SELECTED_LABELS,
      );
    });

    it('returns labels that are selected (part of URL) and result of search', () => {
      state.searchLabelString = 'ACC';
      expect(getters.filteredUnappliedSelectedLabels(state)).toStrictEqual([
        MOCK_FILTERED_UNAPPLIED_SELECTED_LABELS[1],
      ]);
    });
  });

  describe('filteredUnselectedLabels', () => {
    it('returns all labels that are selected (part of URL) no search', () => {
      expect(getters.filteredUnselectedLabels(state)).toStrictEqual(
        MOCK_FILTERED_UNSELECTED_LABELS,
      );
    });

    it('returns labels that are selected (part of URL) and result of search', () => {
      state.searchLabelString = 'ACC';
      expect(getters.filteredUnselectedLabels(state)).toStrictEqual([
        MOCK_FILTERED_UNSELECTED_LABELS[1],
      ]);
    });
  });
});
