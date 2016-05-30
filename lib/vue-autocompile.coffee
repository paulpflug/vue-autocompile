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
  debug: ->
  consumeDebug: (debugSetup) =>
    @debug = debugSetup(pkg: pkgName, nsp:"")
    @debug "debug service consumed", 2
  consumeAutoreload: (reloader) =>
    reloader(pkg:pkgName)
    @debug "autoreload service consumed", 2
  activate: ->
    @disposable = atom.commands.add 'atom-workspace', 'core:save', @handleSave

  deactivate: ->
    @debug "deactivating"
    @disposable.dispose()
    spawn = null
    path = null
    vueCompiler.kill("SIGHUP") if vueCompiler?
    vueCompiler = null

  handleSave: =>
    @debug "got save - is vue?"
    @activeEditor = atom.workspace.getActiveTextEditor()
    return unless @activeEditor?
    path = @activeEditor.getURI()
    return unless path?
    return unless path.match /.*\.vue$/
    @debug "is vue!"
    text = @activeEditor.getText()
    firstComment = text.match /^\s*(\/\/.*)\n*/
    return unless firstComment? and firstComment[1]?
    @debug "found comment"
    paramsString = firstComment[1].replace(/^\/\/\s*/, "").replace(/\s/g,"")

    params = path: path
    for param in paramsString.split ","
      [key, value] = param.split ":"
      continue unless key? and value?
      params[key] = value
    if params.out
      params.hot ?= false
      params.hot = @parseBoolean params.hot
      @debug "rendering"
      @render(params)


  render: (params) ->
    {spawn} = require "child_process"
    path = require "path"
    vueCompiler.kill("SIGHUP") if vueCompiler?
    sh = "sh"
    relativePath = atom.project.relativizePath params.path
    if relativePath[0]? # within a project folder
      tmpString = path.resolve(relativePath[0],"./node_modules/.bin/vue-compiler")
      try
        vueString = tmpString if fs.statSync(tmpString).isFile()
    vueString ?= path.resolve(path.dirname(module.filename),
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
    env = PATH: process.env.PATH
    env.NODE_ENV = "production" unless params.hot

    vueCompiler = spawn sh, args, {
      cwd: process.cwd
      detached: true
      env: env
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
