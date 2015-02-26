url = require 'url'

WebSequencePreviewView = null # Defer until used
renderer = null # Defer until used

createWebSequencePreviewView = (state) ->
  WebSequencePreviewView ?= require './websequence-preview-view'
  new WebSequencePreviewView(state)

isWebSequencePreviewView = (object) ->
  WebSequencePreviewView ?= require './websequence-preview-view'
  object instanceof WebSequencePreviewView

atom.deserializers.add
  name: 'WebSequencePreviewView'
  deserialize: (state) ->
    createWebSequencePreviewView(state) if state.constructor is Object

module.exports =
  config:
    theme:
      type: 'string'
      default: 'magazine'
    liveUpdate:
      type: 'boolean'
      default: true
    openPreviewInSplitPane:
      type: 'boolean'
      default: true

  activate: ->
    atom.commands.add 'atom-workspace',
      'websequence-preview:toggle': =>
        @toggle()
      'websequence-preview:copy-html': =>
        @copyHtml()
      'websequence-preview:toggle-break-on-single-newline': ->
        keyPath = 'websequence-preview.breakOnSingleNewline'
        atom.config.set(keyPath, !atom.config.get(keyPath))

    previewFile = @previewFile.bind(this)
    atom.commands.add '.tree-view .file .name[data-name$=\\.websequence]', 'websequence-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.md]', 'websequence-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mdown]', 'websequence-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mkd]', 'websequence-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.mkdown]', 'websequence-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.ron]', 'websequence-preview:preview-file', previewFile
    atom.commands.add '.tree-view .file .name[data-name$=\\.txt]', 'websequence-preview:preview-file', previewFile

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'websequence-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createWebSequencePreviewView(editorId: pathname.substring(1))
      else
        createWebSequencePreviewView(filePath: pathname)

  toggle: ->
    if isWebSequencePreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  uriForEditor: (editor) ->
    "websequence-preview://editor/#{editor.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  addPreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    options =
      searchAllPanes: true
    if atom.config.get('websequence-preview.openPreviewInSplitPane')
      options.split = 'right'
    atom.workspace.open(uri, options).done (markdownPreviewView) ->
      if isWebSequencePreviewView(markdownPreviewView)
        previousActivePane.activate()

  previewFile: ({target} ) ->
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "websequence-preview://#{encodeURI(filePath)}", searchAllPanes: true

  copyHtml: ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    renderer ?= require './renderer'
    text = editor.getSelectedText() or editor.getText()
    renderer.toHTML text, editor.getPath(), (error, html) =>
      if error
        console.warn('Copying WebSequence as HTML failed', error)
      else
        atom.clipboard.write(html)
