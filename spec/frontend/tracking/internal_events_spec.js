import API from '~/api';
import { mockTracking } from 'helpers/tracking_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import InternalEvents from '~/tracking/internal_events';
import { GITLAB_INTERNAL_EVENT_CATEGORY, SERVICE_PING_SCHEMA } from '~/tracking/constants';

jest.mock('~/api', () => ({
  trackRedisHllUserEvent: jest.fn(),
}));

describe('InternalEvents', () => {
  describe('track_event', () => {
    it('track_event calls trackRedisHllUserEvent with correct arguments', () => {
      const event = 'TestEvent';

      InternalEvents.track_event(event);

      expect(API.trackRedisHllUserEvent).toHaveBeenCalledTimes(1);
      expect(API.trackRedisHllUserEvent).toHaveBeenCalledWith(event);
    });

    it('track_event calls tracking.event functions with correct arguments', () => {
      const trackingSpy = mockTracking(GITLAB_INTERNAL_EVENT_CATEGORY, undefined, jest.spyOn);

      const event = 'TestEvent';

      InternalEvents.track_event(event);

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(GITLAB_INTERNAL_EVENT_CATEGORY, event, {
        context: {
          schema: SERVICE_PING_SCHEMA,
          data: {
            event_name: event,
            data_source: 'redis_hll',
          },
        },
      });
    });
  });

  describe('mixin', () => {
    let wrapper;

    beforeEach(() => {
      const Component = {
        render() {},
        mixins: [InternalEvents.mixin()],
      };
      wrapper = shallowMountExtended(Component);
    });

    it('this.track_event function calls InternalEvent`s track function with an event', () => {
      const event = 'TestEvent';
      const trackEventSpy = jest.spyOn(InternalEvents, 'track_event');

      wrapper.vm.track_event(event);

      expect(trackEventSpy).toHaveBeenCalledTimes(1);
      expect(trackEventSpy).toHaveBeenCalledWith(event);
    });
  });
});
