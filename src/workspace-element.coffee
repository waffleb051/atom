ipc = require 'ipc'
path = require 'path'
{Disposable, CompositeDisposable} = require 'event-kit'
Grim = require 'grim'
scrollbarStyle = require 'scrollbar-style'

module.exports =
class WorkspaceElement extends HTMLElement
  globalTextEditorStyleSheet: null

  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @initializeContent()
    @observeScrollbarStyle()
    @observeTextEditorFontConfig()

  attachedCallback: ->
    @focus()

  detachedCallback: ->
    @subscriptions.dispose()
    @model.destroy()

  initializeContent: ->
    @classList.add 'workspace'
    @setAttribute 'tabindex', -1

    @verticalAxis = document.createElement('atom-workspace-axis')
    @verticalAxis.classList.add('vertical')

    @horizontalAxis = document.createElement('atom-workspace-axis')
    @horizontalAxis.classList.add('horizontal')
    @horizontalAxis.appendChild(@verticalAxis)

    @appendChild(@horizontalAxis)

  observeScrollbarStyle: ->
    @subscriptions.add scrollbarStyle.observePreferredScrollbarStyle (style) =>
      switch style
        when 'legacy'
          @classList.remove('scrollbars-visible-when-scrolling')
          @classList.add("scrollbars-visible-always")
        when 'overlay'
          @classList.remove('scrollbars-visible-always')
          @classList.add("scrollbars-visible-when-scrolling")

  observeTextEditorFontConfig: ->
    @updateGlobalTextEditorStyleSheet()
    @subscriptions.add atom.config.onDidChange 'editor.fontSize', @updateGlobalTextEditorStyleSheet.bind(this)
    @subscriptions.add atom.config.onDidChange 'editor.fontFamily', @updateGlobalTextEditorStyleSheet.bind(this)
    @subscriptions.add atom.config.onDidChange 'editor.lineHeight', @updateGlobalTextEditorStyleSheet.bind(this)

  updateGlobalTextEditorStyleSheet: ->
    styleSheetSource = """
      atom-text-editor {
        font-size: #{atom.config.get('editor.fontSize')}px;
        font-family: #{atom.config.get('editor.fontFamily')};
        line-height: #{atom.config.get('editor.lineHeight')};
      }
    """
    atom.styles.addStyleSheet(styleSheetSource, sourcePath: 'global-text-editor-styles')

  initialize: (@model) ->
    @paneContainer = atom.views.getView(@model.paneContainer)
    @verticalAxis.appendChild(@paneContainer)
    @addEventListener 'focus', @handleFocus.bind(this)

    @panelContainers =
      top: atom.views.getView(@model.panelContainers.top)
      left: atom.views.getView(@model.panelContainers.left)
      right: atom.views.getView(@model.panelContainers.right)
      bottom: atom.views.getView(@model.panelContainers.bottom)
      modal: atom.views.getView(@model.panelContainers.modal)

    @horizontalAxis.insertBefore(@panelContainers.left, @verticalAxis)
    @horizontalAxis.appendChild(@panelContainers.right)

    @verticalAxis.insertBefore(@panelContainers.top, @paneContainer)
    @verticalAxis.appendChild(@panelContainers.bottom)

    @appendChild(@panelContainers.modal)

    this

  getModel: -> @model

  handleFocus: (event) ->
    @model.getActivePane().activate()

  focusPaneViewAbove: -> @paneContainer.focusPaneViewAbove()

  focusPaneViewBelow: -> @paneContainer.focusPaneViewBelow()

  focusPaneViewOnLeft: -> @paneContainer.focusPaneViewOnLeft()

  focusPaneViewOnRight: -> @paneContainer.focusPaneViewOnRight()

  runPackageSpecs: ->
    if activePath = atom.workspace.getActivePaneItem()?.getPath?()
      [projectPath] = atom.project.relativizePath(activePath)
    else
      [projectPath] = atom.project.getPaths()
    ipc.send('run-package-specs', path.join(projectPath, 'spec')) if projectPath

atom.commands.add 'atom-workspace',
  'window:increase-font-size': -> @getModel().increaseFontSize()
  'window:decrease-font-size': -> @getModel().decreaseFontSize()
  'window:reset-font-size': -> @getModel().resetFontSize()
  'application:about': -> ipc.send('command', 'application:about')
  'application:run-all-specs': -> ipc.send('command', 'application:run-all-specs')
  'application:show-preferences': -> ipc.send('command', 'application:show-settings')
  'application:show-settings': -> ipc.send('command', 'application:show-settings')
  'application:quit': -> ipc.send('command', 'application:quit')
  'application:hide': -> ipc.send('command', 'application:hide')
  'application:hide-other-applications': -> ipc.send('command', 'application:hide-other-applications')
  'application:install-update': -> ipc.send('command', 'application:install-update')
  'application:unhide-all-applications': -> ipc.send('command', 'application:unhide-all-applications')
  'application:new-window': -> ipc.send('command', 'application:new-window')
  'application:new-file': -> ipc.send('command', 'application:new-file')
  'application:open': -> ipc.send('command', 'application:open')
  'application:open-file': -> ipc.send('command', 'application:open-file')
  'application:open-folder': -> ipc.send('command', 'application:open-folder')
  'application:open-dev': -> ipc.send('command', 'application:open-dev')
  'application:open-safe': -> ipc.send('command', 'application:open-safe')
  'application:add-project-folder': -> atom.addProjectFolder()
  'application:minimize': -> ipc.send('command', 'application:minimize')
  'application:zoom': -> ipc.send('command', 'application:zoom')
  'application:bring-all-windows-to-front': -> ipc.send('command', 'application:bring-all-windows-to-front')
  'application:open-your-config': -> ipc.send('command', 'application:open-your-config')
  'application:open-your-init-script': -> ipc.send('command', 'application:open-your-init-script')
  'application:open-your-keymap': -> ipc.send('command', 'application:open-your-keymap')
  'application:open-your-snippets': -> ipc.send('command', 'application:open-your-snippets')
  'application:open-your-stylesheet': -> ipc.send('command', 'application:open-your-stylesheet')
  'application:open-license': -> @getModel().openLicense()
  'window:run-package-specs': -> @runPackageSpecs()
  'window:focus-next-pane': -> @getModel().activateNextPane()
  'window:focus-previous-pane': -> @getModel().activatePreviousPane()
  'window:focus-pane-above': -> @focusPaneViewAbove()
  'window:focus-pane-below': -> @focusPaneViewBelow()
  'window:focus-pane-on-left': -> @focusPaneViewOnLeft()
  'window:focus-pane-on-right': -> @focusPaneViewOnRight()
  'window:save-all': -> @getModel().saveAll()
  'window:toggle-invisibles': -> atom.config.set("editor.showInvisibles", not atom.config.get("editor.showInvisibles"))
  'window:log-deprecation-warnings': -> Grim.logDeprecations()
  'window:toggle-auto-indent': -> atom.config.set("editor.autoIndent", not atom.config.get("editor.autoIndent"))
  'pane:reopen-closed-item': -> @getModel().reopenItem()
  'core:close': -> @getModel().destroyActivePaneItemOrEmptyPane()
  'core:save': -> @getModel().saveActivePaneItem()
  'core:save-as': -> @getModel().saveActivePaneItemAs()

if process.platform is 'darwin'
  atom.commands.add 'atom-workspace', 'window:install-shell-commands', -> @getModel().installShellCommands()

module.exports = WorkspaceElement = document.registerElement 'atom-workspace', prototype: WorkspaceElement.prototype
