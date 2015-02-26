path = require 'path'

{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, $$$, ScrollView} = require 'atom-space-pen-views'
Grim = require 'grim'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{File} = require 'pathwatcher'

renderer = require './renderer'

module.exports =
class WebSequencePreviewView extends ScrollView
  @content: ->
    @div class: 'websequence-preview native-key-bindings', tabindex: - 1

  constructor: ({@editorId, @filePath} ) ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable

  attached: ->
    return if @isAttached
    @isAttached = true

    if @editorId?
      @resolveEditor(@editorId)
    else
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateInitialPackages =>
          @subscribeToFilePath(@filePath)

  serialize: ->
    deserializer: 'WebSequencePreviewView'
    filePath: @getPath()
    editorId: @editorId

  destroy: ->
    @disposables.dispose()

  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  onDidChangeModified: (callback) ->
    # No op to suppress deprecation warning
    new Disposable

  onDidChangeWebSequence: (callback) ->
    @emitter.on 'did-change-websequence', callback

  on: (eventName) ->
    if eventName is 'websequence-preview:websequence-changed'
      Grim.deprecate("Use WebSequencePreviewView::onDidChangeWebSequence instead of the 'websequence-preview:websequence-changed' jQuery event")
    super

  subscribeToFilePath: (filePath) ->
    @file = new File(filePath)
    @emitter.emit 'did-change-title'
    @handleEvents()
    @renderWebSequence()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @emitter.emit 'did-change-title' if @editor?
        @handleEvents()
        @renderWebSequence()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    # @disposables.add atom.grammars.onDidAddGrammar => _.debounce((=> @renderWebSequence()), 250)
    # @disposables.add atom.grammars.onDidUpdateGrammar _.debounce((=> @renderWebSequence()), 250)
    #
    atom.commands.add @element,
      'core:move-up': =>
        @scrollUp()
      'core:move-down': =>
        @scrollDown()
      'core:save-as': (event) =>
        event.stopPropagation()
        @saveAs()
      'core:copy': (event) =>
        event.stopPropagation() if @copyToClipboard()
      'websequence-preview:zoom-in': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel + .1)
      'websequence-preview:zoom-out': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel - .1)
      'websequence-preview:reset-zoom': =>
        @css('zoom', 1)

    changeHandler = =>
      @renderWebSequence()

      # TODO: Remove paneForURI call when ::paneForItem is released
      pane = atom.workspace.paneForItem? (this) ? atom.workspace.paneForURI(@getURI())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    if @file?
      @disposables.add @file.onDidChange(changeHandler)
    else if @editor?
      @disposables.add @editor.getBuffer().onDidStopChanging =>
        changeHandler() if atom.config.get 'websequence-preview.liveUpdate'
      @disposables.add @editor.onDidChangePath => @emitter.emit 'did-change-title'
      @disposables.add @editor.getBuffer().onDidSave =>
        changeHandler() unless atom.config.get 'websequence-preview.liveUpdate'
      @disposables.add @editor.getBuffer().onDidReload =>
        changeHandler() unless atom.config.get 'websequence-preview.liveUpdate'

    @disposables.add atom.config.onDidChange 'websequence-preview.breakOnSingleNewline', changeHandler

  renderWebSequence: ->
    @showLoading()
    @getWebSequenceSource().then (source) => @renderWebSequenceText(source) if source?

  getWebSequenceSource: ->
    if @file?
      @file.read()
    else if @editor?
      Promise.resolve(@editor.getText())
    else
      Promise.resolve(null)

  renderWebSequenceText: (text) ->
    renderer.toDOMFragment text, @getPath(), (error, domFragment) =>
      if error
        @showError(error)
      else
        @loading = false
        @empty()
        @append(domFragment)
        @emitter.emit 'did-change-websequence'
        @originalTrigger('websequence-preview:websequence-changed')

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Preview"
    else if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "WebSequence Preview"

  getIconName: ->
    "websequence"

  getURI: ->
    if @file?
      "websequence-preview://#{@getPath()}"
    else
      "websequence-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  getGrammar: ->
    @editor?.getTheme()

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing WebSequence Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @loading = true
    @html $$$ ->
      @div class: 'websequence-spinner', 'Loading WebSequence\u2026'

  copyToClipboard: ->
    return false if @loading

    selection = window.getSelection()
    selectedText = selection.toString()
    selectedNode = selection.baseNode

    # Use default copy event handler if there is selected text inside this view
    return false if selectedText and selectedNode? and (@[0] is selectedNode or $.contains(@[0], selectedNode))

    @getWebSequenceSource().then (source) =>
      return unless source?

      renderer.toHTML source, @getPath(), (error, html) =>
        if error?
          console.warn('Copying WebSequence as HTML failed', error)
        else
          atom.clipboard.write(html)

    true

  saveAs: ->
    return if @loading

    filePath = @getPath()
    if filePath
      filePath += '.html'
    else
      filePath = 'untitled.md.html'
      if projectPath = atom.project.getPath()
        filePath = path.join(projectPath, filePath)

    if htmlFilePath = atom.showSaveDialogSync(filePath)
      # Hack to prevent encoding issues
      # https://github.com/atom/websequence-preview/issues/96
      html = @[0].innerHTML.split('').join('')

      fs.writeFileSync(htmlFilePath, html)
      atom.workspace.open(htmlFilePath)

  isEqual: (other) ->
    @[0] is other? [0] # Compare DOM elements
