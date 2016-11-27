{BufferedProcess} = require 'atom'

module.exports =
  activate: (state) ->
    atom.workspace.observeTextEditors (editor) ->
     editor.onDidSave ->  onSave(editor)

 # action checks if file is being saved is of erlang type
 # and attempt to compile it
 # afterwards perform actions on
 # (@todo beforeCompile,) afterCompile
 # compiling itself may be discared in config in that case extension will
 # work as script runner on file save
 # @todo add wildcards to the config to perform custom aciton for
 # particular  files and/or folders
 onSave = (editor) ->
   if getFromConfig('fileExtensions')?
     fileExtensions = getFromConfig('fileExtensions')
   else
     fileExtensions =
       ['erl', 'S', 'core', 'yrl', 'mib', 'bin', 'rel', 'asn', 'idl']
   l = editor.getPath().split '.'
   ext = l[l.length-1]
   compileErlang(editor, l[l.length-2]) if ext in fileExtensions

showSuccessMessageOnCompile = (wildcards) ->
  if hasOnCompileMessage()? && hasOnCompileMessage()
    message = replaceWildcards(getFromConfig('onCompile').message, wildcards)
    atom.notifications.addSuccess(message)

getCompiledMessage = () ->
  atom.config.settings.erlangAutocompile.onCompile.message

hasOnCompileMessage = () ->
  getFromConfig('onCompile')? &&
  'message' of getFromConfig('onCompile')

hasAfterCompileCommands = () ->
  getFromConfig('afterCompile')? &&
  Object.keys(getFromConfig('afterCompile')).length > 0

replaceWildcards = (str, wildcards) ->
  for card of wildcards
    k = wildcards[card].k
    v = wildcards[card].v
    str = str.replace k, v
  str

#if after compie commands provided runs them in sequence
runAfterCompileCommands = (wildcards) ->
  afterCompileCommands = getFromConfig('afterCompile')
  if afterCompileCommands?
    runCommand(wildcards, afterCompileCommands, 0)

compileErlang = (editor, s) ->
  p = getAbsFileDirectoryPath(s)
  f = extractFileName(editor, p)
  callErlc(p,f, editor)

extractFileName = (editor, p) ->
  editor.getPath().replace p, ""

getAbsFileDirectoryPath = (s) ->
  len = s.lastIndexOf('/')
  p = ''
  append = (p1, p2) -> p1 = p1 + '/' + p2
  p += s[i] for i in [0..len]
  p

#wrapper for buffered process object creation
executeCommand = (command, args, options, stdout, stderr, exit) ->
  process = new BufferedProcess({command, args, options,stdout, stderr, exit})

#runs execte command with 'erlc'
#runs after compile commands
#todo refactor: move wildcards to spearate method
#todo add check fi compilation eing disabled in config
callErlc = (cwd,file,editor) ->
  m = file.split '.'
  module = m[0]
  wildcards =
    cwd :
      k: '%cwd%'
      v: cwd
    file:
      k: '%file%'
      v: file
    module:
      k: '%module%'
      v: module
  options= []
  options['cwd'] = cwd
  stdout = (output) ->
    atom.notifications.addWarning(output) if (output.length>0)
  stderr = (error) ->
    atom.notifications.addError(error) if (error.length>0)
  exit = (code) ->
    if (code == 0)
      showSuccessMessageOnCompile(wildcards) if hasOnCompileMessage()?
      runAfterCompileCommands(wildcards) if hasAfterCompileCommands()

  executeCommand('erlc', [file],options, stdout,stderr,exit)

#true if a starts with b, false otherwise
startsWith = (a, b) ->
  (a.search b) == 0

runCommand = (wildcards, afterCompileCommands, n) ->
  keys = Object.keys(afterCompileCommands)
  if keys.length > n
    settings = afterCompileCommands[keys[n]]
    # for key, settings of afterCompileCommands
    if settings.whenCwd? == false || (settings.whenCwd? && startsWith(wildcards['cwd'].v, settings.whenCwd))
      command = settings.command
      args = settings.args
      for card of wildcards
        k = wildcards[card].k
        v = wildcards[card].v
        args = args.replace k, v
        command = command.replace k, v
      args = args.split " "
      if settings.onSuccess? && settings.onSuccess.message?
        message = settings.onSuccess.message
      options= []
      options['cwd'] = wildcards['cwd'].v
      stdout = (output) ->
        atom.notifications.addWarning(output) if (output.length>0)
      stderr = (error) ->
        atom.notifications.addError(error) if (error.length>0)
      exit = (code) ->
        if (code == 0)
          atom.notifications.addSuccess(
            replaceWildcards(message, wildcards)) if message?
          runCommand(wildcards, afterCompileCommands, ++n)
      executeCommand(command, args, options,stdout,stderr,exit)

#attempt to get settigns related to the plugin from atom config
getFromConfig = (prop) ->
  if atom.config.settings.erlangAutocompile? &&
     (prop of atom.config.settings.erlangAutocompile)?
    atom.config.settings.erlangAutocompile[prop]
