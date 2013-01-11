{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
$ = require 'jquery'
fs = require 'fs'

module.exports =
class FuzzyFinder extends SelectList
  @activate: (rootView) ->
    @instance = new FuzzyFinder(rootView)
    rootView.command 'fuzzy-finder:toggle-file-finder', => @instance.toggleFileFinder()
    rootView.command 'fuzzy-finder:toggle-buffer-finder', => @instance.toggleBufferFinder()

  @viewClass: ->
    [super, 'fuzzy-finder'].join(' ')

  allowActiveEditorChange: null
  maxItems: 10
  projectPaths: null
  reloadProjectPaths: true

  initialize: (@rootView) ->
    super

    @subscribe $(window), 'focus', => @reloadProjectPaths = true
    @observeConfig 'fuzzy-finder.ignoredNames', => @reloadProjectPaths = true

    @miniEditor.command 'editor:split-left', =>
      @splitOpenPath (editor, session) -> editor.splitLeft(session)
    @miniEditor.command 'editor:split-right', =>
      @splitOpenPath (editor, session) -> editor.splitRight(session)
    @miniEditor.command 'editor:split-down', =>
      @splitOpenPath (editor, session) -> editor.splitDown(session)
    @miniEditor.command 'editor:split-up', =>
      @splitOpenPath (editor, session) -> editor.splitUp(session)

  itemForElement: (path) ->
    $$ ->
      @li =>
        ext = fs.extension(path)
        if fs.isCompressedExtension(ext)
          typeClass = 'compressed-name'
        else if fs.isImageExtension(ext)
          typeClass = 'image-name'
        else if fs.isPdfExtension(ext)
          typeClass = 'pdf-name'
        else
          typeClass = 'text-name'
        @span fs.base(path), class: "file #{typeClass}"
        if folder = fs.directory(path)
          @span "- #{folder}/", class: 'directory'

  openPath: (path) ->
    @rootView.open(path, {@allowActiveEditorChange}) if path

  splitOpenPath: (fn) ->
    path = @getSelectedElement()
    return unless path

    editor = @rootView.getActiveEditor()
    if editor
      fn(editor, @rootView.project.buildEditSessionForPath(path))
    else
      @openPath(path)

  confirmed : (path) ->
    return unless path.length
    @cancel()
    @openPath(path)

  cancelled: ->
    @miniEditor.setText('')
    @rootView.focus() if @miniEditor.isFocused

  toggleFileFinder: ->
    if @hasParent()
      @cancel()
    else
      return unless @rootView.project.getPath()?
      @allowActiveEditorChange = false
      @populateProjectPaths()
      @attach()

  toggleBufferFinder: ->
    if @hasParent()
      @cancel()
    else
      @allowActiveEditorChange = true
      @populateOpenBufferPaths()
      @attach() if @paths?.length

  populateProjectPaths: ->
    if @projectPaths?.length > 0
      @setArray(@projectPaths)
    else
      @setLoading("Indexing...")

    if @reloadProjectPaths
      @rootView.project.getFilePaths().done (paths) =>
        ignoredNames = config.get("fuzzyFinder.ignoredNames") or []
        ignoredNames = ignoredNames.concat(config.get("core.ignoredNames") or [])
        @projectPaths = paths
        if ignoredNames
          @projectPaths = @projectPaths.filter (path) ->
            for segment in path.split("/")
              return false if _.contains(ignoredNames, segment)
            return true

        @reloadProjectPaths = false
        @setArray(@projectPaths)

  populateOpenBufferPaths: ->
    @paths = @rootView.getOpenBufferPaths().map (path) =>
      @rootView.project.relativize(path)
    @setArray(@paths)

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()
