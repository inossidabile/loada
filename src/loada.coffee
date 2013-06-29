$head = document.getElementsByTagName("head")[0]

class @Loada
  Progress: class
    constructor: (@count, @progressCallback) ->
      @data = {}

    set: (key, percent) ->
      @data[key] = Math.min(percent, 100.0)
      @progressCallback? @total()

    total: ->
      total = 0
      total += Math.round(percent/@count*100)/100 for key, percent of @data
      total

  #
  # localStorage cache entries keys are prefixed with this value
  #
  prefix: 'loada'

  #
  # Alias for the #{constructor}
  #
  @set: ->
    new @ arguments...

  #
  # @param [String]   Name of the libraries set
  # @param [Object]
  #  
  constructor: (@set, options) ->
    @options =
      localStorage: true

    @requires =
      input: []
      set: {}
      length: 0

    @set ||= '*'
    @options[k] = v for k,v of options if options
    @setup()

  setup: ->
    if @options.localStorage
      @storage = localStorage[@key()] || {}

      if typeof(@storage) == 'string'
        @storage = JSON.parse(localStorage[@key()])

  key: -> "#{@prefix}.#{@set}"

  save: ->
    localStorage[@key()] = JSON.stringify @storage

  clear: -> delete localStorage[@key()]

  get: (key) ->
    @storage[key]?.source

  expire: ->
    now = new Date

    byDate = (library) =>
      library.expirationDate && new Date(library.expirationDate) <= now

    byExistance = (library) =>
      !@requires.set[key]

    byRevision = (library) =>
      @requires.set[key].revision != library.revision

    for key, library of @storage

      if byDate(library) || byExistance(library) || byRevision(library)
        delete @storage[key]

  require: (libraries) ->
    libraries = [libraries] unless libraries instanceof Array

    for library in libraries
      library.key  ||= library.url
      library.type ||= library.url?.split('.').pop()

      if library.type == 'js' || library.type == 'css'
        @requires.set[library.key] = library
      else
        console.error "Unknown asset type for #{library.url} – skipped"

    @requires.length += libraries.length
    @requires.input.push libraries

  load: (callback) ->
    callback ||= {}
    @expire() if @options.localStorage

    progress = new @Progress(@requires.length, callback.progress)
    loaders  = 0

    @_ensureSizes callback.progress?, =>
      for group in @requires.input
        loaders++

        @_loadGroup group.slice(0), progress, =>
          loaders--
          if loaders == 0
            @save()
            callback.success?()

  _ensureSizes: (perform, callback) ->
    unless perform
      library.size = 0 for key, library of @requires.set
      return callback()

    requests = 0

    for key, library of @requires.set
      do (library) =>
        unless library.size?
          requests++

          @_ajax 'HEAD', library.url, (xhr) ->
            requests--
            size = xhr.getResponseHeader('Content-Length')
            size = parseInt(size) if size
            library.size = size || 0
            callback() if requests == 0

  _loadGroup: (group, progress, callback) =>
    library = group.shift()

    return callback() unless library

    if @options.localStorage && @storage[library.key]
      progress?.set library.key, 100
      @_inject @storage[library.key]
      @_loadGroup group, progress, callback
    else
      method = if @options.localStorage
        "_loadAJAX"
      else
        "_loadInline"

      @[method] library, progress, =>
        @storage[library.key] = library if @options.localStorage
        @_inject library
        @_loadGroup group, progress, callback


  _loadAJAX: (library, progress, callback) ->
    xhr = @_ajax 'GET', library.url, (xhr) =>
      library.source = xhr.responseText
      clearInterval poller
      progress?.set library.key, 100
      callback()

    if library.size > 0
      poller = setInterval (->
        percent = Math.round(xhr.responseText.length / library.size * 100 * 100) / 100
        progress?.set library.key, percent
      ),
      100

  _loadInline: (library, progress, callback) ->
    if library.type != 'js'
      console.error "Attempt to load something other than JS without localStorage."
      console.error "#{library.url} is not loaded!"
      progress?.set library.key, 100
      return callback()

    script = document.createElement "script"
    done   = false

    proceed = ->
      if !done && (!@readyState? || @readyState == "loaded" || @readyState == "complete")
        done = true
        progress?.set library.key, 100
        callback?()
        script.onload = script.onreadystatechange = null

    script.onload = script.onreadystatechange = proceed

    script.src = library.url
    $head.appendChild script

  _inject: (library) ->
    if library.type == 'js'
      script = document.createElement "script"
      script.defer = true
      script.text = library.source
      $head.appendChild script
    else
      style = document.createElement "style"
      style.innerHTML = library.source
      $head.appendChild style

  _ajax: (method, url, callback) ->
    if window.XMLHttpRequest
      xhr = new XMLHttpRequest
    else
      xhr = new ActiveXObject 'Microsoft.XMLHTTP'

    xhr.open method, url, 1
    xhr.onreadystatechange = -> callback?(xhr) if xhr.readyState > 3
    xhr.send()

    xhr