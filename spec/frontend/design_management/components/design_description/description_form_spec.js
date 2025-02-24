import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import DescriptionForm from '~/design_management/components/design_description/description_form.vue';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import updateDesignDescriptionMutation from '~/design_management/graphql/mutations/update_design_description.mutation.graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { mockTracking } from 'helpers/tracking_helper';
import { designFactory, designUpdateFactory } from '../../mock_data/apollo_mock';

jest.mock('~/behaviors/markdown/render_gfm');

Vue.use(VueApollo);

describe('Design description form', () => {
  const formFieldProps = {
    id: 'design-description',
    name: 'design-description',
    placeholder: 'Write a comment or drag your files here…',
    'aria-label': 'Design description',
  };
  const mockDesign = designFactory();
  const mockDesignVariables = {
    fullPath: '',
    iid: '1',
    filenames: ['test.jpg'],
    atVersion: null,
  };

  const mockDesignResponse = designUpdateFactory();
  const mockDesignUpdateMutationHandler = jest.fn().mockResolvedValue(mockDesignResponse);
  let wrapper;
  let mockApollo;

  const createComponent = ({
    design = mockDesign,
    descriptionText = '',
    showEditor = false,
    isSubmitting = false,
    designVariables = mockDesignVariables,
    contentEditorOnIssues = false,
    designUpdateMutationHandler = mockDesignUpdateMutationHandler,
  } = {}) => {
    mockApollo = createMockApollo([[updateDesignDescriptionMutation, designUpdateMutationHandler]]);
    wrapper = mountExtended(DescriptionForm, {
      propsData: {
        design,
        markdownPreviewPath: '/gitlab-org/gitlab-test/preview_markdown?target_type=Issue',
        designVariables,
      },
      provide: {
        glFeatures: {
          contentEditorOnIssues,
        },
      },
      apolloProvider: mockApollo,
      data() {
        return {
          formFieldProps,
          descriptionText,
          showEditor,
          isSubmitting,
        };
      },
    });
  };

  afterEach(() => {
    mockApollo = null;
  });

  const findDesignContent = () => wrapper.findByTestId('design-description-content');
  const findDesignNoneBlock = () => wrapper.findByTestId('design-description-none');
  const findEditDescriptionButton = () => wrapper.findByTestId('edit-description');
  const findSaveDescriptionButton = () => wrapper.findByTestId('save-description');
  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findTextarea = () => wrapper.find('textarea');
  const findCheckboxAtIndex = (index) => wrapper.findAll('input[type="checkbox"]').at(index);
  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('user has updateDesign permission', () => {
    let trackingSpy;

    const ctrlKey = {
      ctrlKey: true,
    };
    const metaKey = {
      metaKey: true,
    };
    const mockDescription = 'Hello world';
    const errorMessage = 'Could not update description. Please try again.';

    beforeEach(() => {
      trackingSpy = mockTracking(undefined, null, jest.spyOn);

      createComponent();
    });

    it('renders description content with the edit button', () => {
      expect(findDesignContent().text()).toEqual('Test description');
      expect(findEditDescriptionButton().exists()).toBe(true);
    });

    it('renders none when description is empty', () => {
      createComponent({ design: designFactory({ description: '', descriptionHtml: '' }) });

      expect(findDesignNoneBlock().text()).toEqual('None');
    });

    it('renders save button when editor is open', () => {
      createComponent({
        design: designFactory({ description: '', descriptionHtml: '' }),
        showEditor: true,
      });

      expect(findSaveDescriptionButton().exists()).toBe(true);
      expect(findSaveDescriptionButton().attributes('disabled')).toBeUndefined();
    });

    it('renders the markdown editor with default props', () => {
      createComponent({
        showEditor: true,
        descriptionText: 'Test description',
      });

      expect(findMarkdownEditor().exists()).toBe(true);
      expect(findMarkdownEditor().props()).toMatchObject({
        value: 'Test description',
        renderMarkdownPath: '/gitlab-org/gitlab-test/preview_markdown?target_type=Issue',
        enableContentEditor: false,
        formFieldProps,
        autofocus: true,
        enableAutocomplete: true,
        supportsQuickActions: false,
        autosaveKey: `Issue/${getIdFromGraphQLId(mockDesign.issue.id)}/Design/${getIdFromGraphQLId(
          mockDesign.id,
        )}`,
        markdownDocsPath: '/help/user/markdown',
      });
    });

    describe.each`
      isKeyEvent | assertionName              | key       | keyData
      ${true}    | ${'Ctrl + Enter keypress'} | ${'ctrl'} | ${ctrlKey}
      ${true}    | ${'Meta + Enter keypress'} | ${'meta'} | ${metaKey}
      ${false}   | ${'Save button click'}     | ${''}     | ${null}
    `('when form is submitted via $assertionName', ({ isKeyEvent, keyData }) => {
      let mockDesignUpdateResponseHandler;

      beforeEach(async () => {
        mockDesignUpdateResponseHandler = jest.fn().mockResolvedValue(
          designUpdateFactory({
            description: mockDescription,
            descriptionHtml: `<p data-sourcepos="1:1-1:16" dir="auto">${mockDescription}</p>`,
          }),
        );

        createComponent({
          showEditor: true,
          designUpdateMutationHandler: mockDesignUpdateResponseHandler,
        });

        findMarkdownEditor().vm.$emit('input', 'Hello world');
        if (isKeyEvent) {
          findTextarea().trigger('keydown.enter', keyData);
        } else {
          findSaveDescriptionButton().vm.$emit('click');
        }

        await nextTick();
      });

      it('hides form and calls mutation', async () => {
        expect(mockDesignUpdateResponseHandler).toHaveBeenCalledWith({
          input: {
            description: 'Hello world',
            id: 'gid::/gitlab/Design/1',
          },
        });

        await waitForPromises();

        expect(findMarkdownEditor().exists()).toBe(false);
      });

      it('tracks submit action', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'editor_type_used', {
          context: 'Design',
          editorType: 'editor_type_plain_text_editor',
          label: 'editor_tracking',
        });
      });
    });

    it('shows error message when mutation fails', async () => {
      const failureHandler = jest.fn().mockRejectedValue(new Error(errorMessage));
      createComponent({
        showEditor: true,
        descriptionText: 'Hello world',
        designUpdateMutationHandler: failureHandler,
      });

      findMarkdownEditor().vm.$emit('input', 'Hello world');
      findSaveDescriptionButton().vm.$emit('click');

      await waitForPromises();

      expect(findAlert().exists()).toBe(true);
      expect(findAlert().text()).toBe(errorMessage);
    });
  });

  describe('content has checkboxes', () => {
    const mockCheckboxDescription = '- [x] todo 1\n- [ ] todo 2';
    const mockCheckboxDescriptionHtml = `<ul dir="auto" class="task-list" data-sourcepos="1:1-4:0">
    <li class="task-list-item" data-sourcepos="1:1-2:15">
    <input checked="" class="task-list-item-checkbox" type="checkbox"> todo 1</li>
    <li class="task-list-item" data-sourcepos="2:1-2:15">
    <input class="task-list-item-checkbox" type="checkbox"> todo 2</li>
    </ul>`;
    const checkboxDesignDescription = designFactory({
      updateDesign: true,
      description: mockCheckboxDescription,
      descriptionHtml: mockCheckboxDescriptionHtml,
    });
    const mockCheckedDescriptionUpdateResponseHandler = jest.fn().mockResolvedValue(
      designUpdateFactory({
        description: '- [x] todo 1\n- [x] todo 2',
        descriptionHtml: `<ul dir="auto" class="task-list" data-sourcepos="1:1-4:0">
        <li class="task-list-item" data-sourcepos="1:1-2:15">
        <input checked="" class="task-list-item-checkbox" type="checkbox"> todo 1</li>
        <li class="task-list-item" data-sourcepos="2:1-2:15">
        <input class="task-list-item-checkbox" type="checkbox"> todo 2</li>
        </ul>`,
      }),
    );
    const mockUnCheckedDescriptionUpdateResponseHandler = jest.fn().mockResolvedValue(
      designUpdateFactory({
        description: '- [ ] todo 1\n- [ ] todo 2',
        descriptionHtml: `<ul dir="auto" class="task-list" data-sourcepos="1:1-4:0">
        <li class="task-list-item" data-sourcepos="1:1-2:15">
        <input class="task-list-item-checkbox" type="checkbox"> todo 1</li>
        <li class="task-list-item" data-sourcepos="2:1-2:15">
        <input class="task-list-item-checkbox" type="checkbox"> todo 2</li>
        </ul>`,
      }),
    );

    it.each`
      assertionName  | mockDesignUpdateResponseHandler                  | checkboxIndex | checked  | expectedDesignDescription
      ${'checked'}   | ${mockCheckedDescriptionUpdateResponseHandler}   | ${1}          | ${true}  | ${'- [x] todo 1\n- [x] todo 2'}
      ${'unchecked'} | ${mockUnCheckedDescriptionUpdateResponseHandler} | ${0}          | ${false} | ${'- [ ] todo 1\n- [ ] todo 2'}
    `(
      'updates the store object when checkbox is $assertionName',
      async ({
        mockDesignUpdateResponseHandler,
        checkboxIndex,
        checked,
        expectedDesignDescription,
      }) => {
        createComponent({
          design: checkboxDesignDescription,
          descriptionText: mockCheckboxDescription,
          designUpdateMutationHandler: mockDesignUpdateResponseHandler,
        });

        findCheckboxAtIndex(checkboxIndex).setChecked(checked);

        expect(mockDesignUpdateResponseHandler).toHaveBeenCalledWith({
          input: {
            description: expectedDesignDescription,
            id: 'gid::/gitlab/Design/1',
          },
        });

        await waitForPromises();

        expect(renderGFM).toHaveBeenCalled();
      },
    );

    it('disables checkbox while updating', () => {
      createComponent({
        design: checkboxDesignDescription,
        descriptionText: mockCheckboxDescription,
      });

      findCheckboxAtIndex(1).setChecked();

      expect(findCheckboxAtIndex(1).attributes().disabled).toBeDefined();
    });
  });

  describe('user has no updateDesign permission', () => {
    beforeEach(() => {
      const designWithNoUpdateUserPermission = designFactory({
        updateDesign: false,
      });
      createComponent({ design: designWithNoUpdateUserPermission });
    });

    it('does not render edit button', () => {
      expect(findEditDescriptionButton().exists()).toBe(false);
    });
  });
});
