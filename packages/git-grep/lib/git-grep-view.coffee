{View} = require 'atom'
{SelectListView} = require 'atom'
path = require 'path'
{$$, Point, SelectListView} = require 'atom'

module.exports =
class GitGrepView extends SelectListView
  getFilterKey: -> 'filePath'

  initialize: (serializeState) ->
    super
    @addClass('git-grep overlay from-top')

  viewForItem: (line) ->
    """<li>
      #{line.filePath}
      :
      <span class='text-info'>L#{line.line}</span>
      /
      <span class='text-info'>L#{line.rootPath}</span>
      <br/>
      <span class='text-subtle'>#{line.content}</span>
    </li>"""

  confirmed: (item) ->
    @openPath (path.join atom.project.rootDirectories[0].path, item.filePath), item.line-1
    @hide()

  serialize: ->

  openPath: (filePath, lineNumber) ->
    if filePath
      atom.workspaceView.open(filePath).done => @moveToLine(lineNumber)

  moveToLine: (lineNumber=-1) ->
    return unless lineNumber >= 0
    if editorView = atom.workspaceView.getActiveView()
      position = new Point(lineNumber)
      editorView.scrollToBufferPosition(position, center: true)
      editorView.editor.setCursorBufferPosition(position)
      editorView.editor.moveCursorToFirstCharacterOfLine()

  destroy: ->
    @detach()
