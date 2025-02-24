import { DEFAULT_PER_PAGE } from '~/api';
import axios from '../lib/utils/axios_utils';
import { buildApiUrl } from './api_utils';

const GROUP_PATH = '/api/:version/groups/:id';
const GROUPS_PATH = '/api/:version/groups.json';
const GROUP_MEMBERS_PATH = '/api/:version/groups/:id/members';
const GROUP_ALL_MEMBERS_PATH = '/api/:version/groups/:id/members/all';
const DESCENDANT_GROUPS_PATH = '/api/:version/groups/:id/descendant_groups';
const GROUP_TRANSFER_LOCATIONS_PATH = 'api/:version/groups/:id/transfer_locations';

const axiosGet = (url, query, options, callback) => {
  return axios
    .get(url, {
      params: {
        search: query,
        per_page: DEFAULT_PER_PAGE,
        ...options,
      },
    })
    .then(({ data, headers }) => {
      callback(data);

      return { data, headers };
    });
};

export function getGroups(query, options, callback = () => {}) {
  const url = buildApiUrl(GROUPS_PATH);
  return axiosGet(url, query, options, callback);
}

export function getDescendentGroups(parentGroupId, query, options, callback = () => {}) {
  const url = buildApiUrl(DESCENDANT_GROUPS_PATH.replace(':id', parentGroupId));
  return axiosGet(url, query, options, callback);
}

export function updateGroup(groupId, data = {}) {
  const url = buildApiUrl(GROUP_PATH).replace(':id', groupId);

  return axios.put(url, data);
}

export const getGroupTransferLocations = (groupId, params = {}) => {
  const url = buildApiUrl(GROUP_TRANSFER_LOCATIONS_PATH).replace(':id', groupId);
  const defaultParams = { per_page: DEFAULT_PER_PAGE };

  return axios.get(url, { params: { ...defaultParams, ...params } });
};

export const getGroupMembers = (groupId, inherited = false) => {
  const path = inherited ? GROUP_ALL_MEMBERS_PATH : GROUP_MEMBERS_PATH;
  const url = buildApiUrl(path).replace(':id', groupId);

  return axios.get(url);
};
