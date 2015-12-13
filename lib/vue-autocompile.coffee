log = null
reloader = null
spawn = null
path = null
vueCompiler = null
pkgName = "vue-autocompile"

module.exports = new class VueAutocompile
  config:
    debug:
      type: "integer"
      default: 0
      minimum: 0
  activate: ->
    if atom.inDevMode()
      setTimeout (->
        reloaderSettings = pkg:pkgName,folders:["lib"]
        try
          reloader ?= require("atom-package-reloader")(reloaderSettings)
        ),500

    unless log?
      log = require("atom-simple-logger")(pkg:pkgName,nsp:"main")
      log "activating"
    @disposable = atom.commands.add 'atom-workspace', 'core:save', @handleSave

  deactivate: ->
    log "deactivating"
    @disposable.dispose()
    log = null
    reloader?.dispose()
    reloader = null
    spawn = null
    path = null
    vueCompiler.kill("SIGHUP") if vueCompiler?
    vueCompiler = null

  handleSave: =>
    log "got save - is vue?"
    @activeEditor = atom.workspace.getActiveTextEditor()
    return unless @activeEditor?
    path = @activeEditor.getURI()
    return unless path.match /.*\.vue$/
    log "is vue!"
    text = @activeEditor.getText()
    firstComment = text.match /^\s*(\/\/.*)\n*/
    return unless firstComment? and firstComment[1]?
    log "found comment"
    paramsString = firstComment[1].replace(/^\/\/\s*/, "").replace(/\s/g,"")

    params = path: path
    for param in paramsString.split ","
      [key, value] = param.split ":"
      continue unless key? and value?
      params[key] = value
    unless params.out?
      atom.notifications.addError "no output path provided"
    params.compress = true unless params.compress?
    params.compress = @parseBoolean params.compress
    log "rendering"
    @render(params)


  render: (params) ->
    {spawn} = require "child_process"
    path = require "path"
    vueCompiler.kill("SIGHUP") if vueCompiler?
    sh = "sh"
    vueString = path.resolve(path.dirname(module.filename),
                            "../node_modules/.bin/vue-compiler")
    #unless params.compress
      #vueString += " --pretty"
    outPath = path.resolve(path.dirname(params.path),params.out)
    vueString += " --out #{outPath}/"
    vueString += " #{params.path}"
    args = ["-c",vueString]
    if process.platform == "win32"
      sh = "cmd"
      args[0] = "/c"
    vueCompiler = spawn sh, args, {
      cwd: process.cwd
      detached: true
      env: PATH:process.env.PATH
    }
    stderrData = []
    vueCompiler.stderr.setEncoding("utf8")
    vueCompiler.stderr.on "data", (data) ->
      stderrData.push data
    vueCompiler.on "close", (code) ->
      if code
        atom.notifications.addError "compiling failed", detail:stderrData
      else
        atom.notifications.addSuccess(outPath + path.sep +
          path.basename(params.path,".vue") +
          ".js created")

  parseBoolean: (value) ->
    (value is 'true' or value is 'yes' or value is 1 or value is true) and
      value isnt 'false' and value isnt 'no' and value isnt 0 and value isnt false
