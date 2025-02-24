import $ from 'jquery';

import Api from '~/api';
import initPopover from '~/blob/suggest_gitlab_ci_yml';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import toast from '~/vue_shared/plugins/global_toast';

import BlobCiYamlSelector from './template_selectors/ci_yaml_selector';
import DockerfileSelector from './template_selectors/dockerfile_selector';
import GitignoreSelector from './template_selectors/gitignore_selector';
import LicenseSelector from './template_selectors/license_selector';

export default class FileTemplateMediator {
  constructor({ editor, currentAction, projectId }) {
    this.editor = editor;
    this.currentAction = currentAction;
    this.projectId = projectId;

    this.initTemplateSelectors();
    this.initDomElements();
    this.initDropdowns();
    this.initPageEvents();
    this.cacheFileContents();
  }

  initTemplateSelectors() {
    // Order dictates template type dropdown item order
    this.templateSelectors = [
      GitignoreSelector,
      BlobCiYamlSelector,
      DockerfileSelector,
      LicenseSelector,
    ].map((TemplateSelectorClass) => new TemplateSelectorClass({ mediator: this }));
  }

  initDomElements() {
    const $templatesMenu = $('.template-selectors-menu');
    const $undoMenu = $templatesMenu.find('.template-selectors-undo-menu');
    const $fileEditor = $('.file-editor');

    this.$templatesMenu = $templatesMenu;
    this.$undoMenu = $undoMenu;
    this.$undoBtn = $undoMenu.find('button');
    this.$templateSelectors = $templatesMenu.find('.template-selector-dropdowns-wrap');
    this.$filenameInput = $fileEditor.find('.js-file-path-name-input');
    this.$fileContent = $fileEditor.find('#file-content');
    this.$commitForm = $fileEditor.find('form');
    this.$navLinks = $fileEditor.find('.nav-links');
  }

  initDropdowns() {
    if (this.currentAction !== 'create') {
      this.hideTemplateSelectorMenu();
    }

    this.displayMatchedTemplateSelector();
  }

  initPageEvents() {
    this.listenForFilenameInput();
    this.listenForPreviewMode();
  }

  listenForFilenameInput() {
    this.$filenameInput.on('keyup blur', () => {
      this.displayMatchedTemplateSelector();
    });
  }

  listenForPreviewMode() {
    this.$navLinks.on('click', 'a', (e) => {
      const urlPieces = e.target.href.split('#');
      const hash = urlPieces[1];
      if (hash === 'preview') {
        this.hideTemplateSelectorMenu();
      } else if (hash === 'editor' && this.templateSelectors.find((sel) => sel.dropdown !== null)) {
        this.showTemplateSelectorMenu();
      }
    });
  }

  selectTemplateFile(selector, query, data) {
    const self = this;
    const { name } = selector.config;
    const suggestCommitChanges = document.querySelector('.js-suggest-gitlab-ci-yml-commit-changes');

    selector.renderLoading();

    this.fetchFileTemplate(selector.config.type, query, data)
      .then((file) => {
        this.setEditorContent(file);
        this.setFilename(name);
        selector.renderLoaded();

        toast(__(`${query} template applied`), {
          action: {
            text: __('Undo'),
            onClick: (e, toastObj) => {
              self.restoreFromCache();
              toastObj.hide();
            },
          },
        });

        if (suggestCommitChanges) {
          initPopover(suggestCommitChanges);
        }
      })
      .catch((err) =>
        createAlert({
          message: __(`An error occurred while fetching the template: ${err}`),
        }),
      );
  }

  displayMatchedTemplateSelector() {
    const currentInput = this.getFilename();
    const matchedSelector = this.templateSelectors.find((sel) =>
      sel.config.pattern.test(currentInput),
    );
    const currentSelector = this.templateSelectors.find((sel) => !sel.isHidden());

    if (matchedSelector) {
      if (currentSelector) {
        currentSelector.hide();
      }
      matchedSelector.show();
      this.showTemplateSelectorMenu();
    } else {
      this.hideTemplateSelectorMenu();
    }
  }

  fetchFileTemplate(type, query, data = {}) {
    return new Promise((resolve) => {
      const resolveFile = (file) => resolve(file);

      Api.projectTemplate(this.projectId, type, query, data, resolveFile);
    });
  }

  setEditorContent(file) {
    if (!file && file !== '') return;

    const newValue = file.content || file;

    this.editor.setValue(newValue, 1);

    this.editor.focus();

    this.editor.navigateFileStart();
  }

  hideTemplateSelectorMenu() {
    this.$templatesMenu.hide();
  }

  showTemplateSelectorMenu() {
    this.$templatesMenu.show();
    this.cacheToggleText();
  }

  cacheToggleText() {
    this.cachedToggleText = this.getTemplateSelectorToggleText();
  }

  cacheFileContents() {
    this.cachedContent = this.editor.getValue();
    this.cachedFilename = this.getFilename();
  }

  restoreFromCache() {
    this.setEditorContent(this.cachedContent);
    this.setFilename(this.cachedFilename);
    this.setTemplateSelectorToggleText();
  }

  getTemplateSelectorToggleText() {
    return this.$templateSelectors
      .find('.js-template-selector-wrap:visible .dropdown-toggle-text')
      .text();
  }

  setTemplateSelectorToggleText() {
    return this.$templateSelectors
      .find('.js-template-selector-wrap:visible .dropdown-toggle-text')
      .text(this.cachedToggleText);
  }

  getFilename() {
    return this.$filenameInput.val();
  }

  setFilename(name) {
    const input = this.$filenameInput.get(0);
    if (name !== undefined && input.value !== name) {
      input.value = name;
      input.dispatchEvent(new Event('change'));
    }
  }
}
