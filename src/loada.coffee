$head = document.getElementsByTagName("head")[0]

#
# Loada is the kickass in-browser assets (JS/CSS) loader supporting localStorage
# and progress tracking.
#
# @see https://github.com/inossidabile/loada/
#
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
      prefix: 'loada'
      localStorage: true

    @requires =
      input: []
      set: {}
      length: 0

    @set ||= '*'
    @options[k] = v for k,v of options if options
    @key = "#{@options.prefix}.#{@set}"

    @setup()

  #
  # Loads current available cache for the current set into the instance
  #
  setup: ->
    if @options.localStorage
      @storage = localStorage[@key] || {}

      if typeof(@storage) == 'string'
        @storage = JSON.parse(localStorage[@key])
    else
      @storage = {}

  #
  # Cleans up current state
  #
  # Removes entries that are:
  #   * expired by date (`expires` option)
  #   * got new revision (`revision` option)
  #   * not found in the current requires list
  #
  expire: ->
    if @options.localStorage
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

  #
  # Saves current set state to localStorage
  #
  save: ->
    if @options.localStorage
      localStorage[@key] = JSON.stringify @storage

  #
  # Removes localStorage entry bound to current set
  #
  clear: ->
    if @options.localStorage
      delete localStorage[@key]

  #
  # Gets raw source of an asset
  #
  # @param key [String]       Key of the asset
  #
  get: (key) ->
    @storage[key]?.source



  #
  # Adds library that should be loaded
  #
  # All the libraries passed within one call will be loaded
  # successive. Separate {#require} calls are loading in parallel.
  #
  # Library object consists of the following options:
  #   * **url**: location of the asset to load
  #   * **key**: storage key (default to url)
  #   * **type**: js/css (defaults to url extension parsing)
  #   * **revision**: manual revision number – triggers cache bust whenever it changes
  #   * **expires**: amount of hours to keep entry for (defaults to unlimited cache)
  #   * **cache**: whether localStorage should be used for particular asset
  #   * **size**: asset download size (defaults to additional HEAD request result)
  #
  # @param libraries [Object]     Library object
  #
  require: (libraries...) ->
    for library in libraries
      library.key  ||= library.url
      library.type ||= library.url?.split('.').pop()
      library.cache = true unless library.cache?
      library.require = true unless library.require?

      if library.expires
        now = new Date
        library.expirationDate = now.setTime(now.getTime() + library.expires*60*60*1000)

      if library.type == 'js' || library.type == 'css' || library.type == 'text'
        @requires.set[library.key] = library
      else
        console.error "Unknown asset type for #{library.url} – skipped"

    @requires.length += libraries.length
    @requires.input.push libraries

  #
  # Starts the inclusion of required libraries
  #
  # Accepts following options:
  #   * **success**: gets called as soon as all the assets are loaded
  #   * **progress(percent)**: ticks from time to time passing you curent download progress
  #
  # @param [Object] callbacks       List of callbacks
  #
  load: (callbacks) ->
    callbacks ||= {}
    @expire()

    progress = new @Progress(@requires.length, callbacks.progress)
    loaders  = 0

    @_ensureSizes callbacks.progress?, =>
      for group in @requires.input
        loaders++

        @_loadGroup group.slice(0), progress, =>
          loaders--
          if loaders == 0
            @save()
            callbacks.success?()

  #
  # Ensures every asset has 'size' option
  #
  # Runs HEAD request trying to parse Content-Length header for
  # those that don't have.
  #
  # @private
  #
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

  #
  # Loads one require group successively
  #
  # @private
  #
  _loadGroup: (group, progress, callback) =>
    results = []

    for library in group
      if @storage[library.key] && library.cache
        progress?.set library.key, 100
        results.push @storage[library.key]
      else
        method = if @options.localStorage || !library.require
          "_loadAJAX"
        else
          "_loadInline"

        @[method] library, progress, =>
          results.push library
          if results.length == group.length
            @_inject results
            callback()

    if results.length == group.length
      @_inject results
      callback()

  #
  # Loads one asset by AJAX query and stores it into instance
  #
  # @private
  #
  _loadAJAX: (library, progress, callback) ->
    xhr = @_ajax 'GET', library.url, (xhr) =>
      @storage[library.key] = library if library.cache
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

  #
  # Loads one asset by inlining it into DOM
  #
  # @private
  #
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

  #
  # Activates downloaded asset
  #
  # @private
  #
  _inject: (libraries) ->
    libraries = [].concat(libraries)

    for library in libraries when library.require && library.source
      if library.type == 'js'
        script = document.createElement "script"
        script.defer = true
        script.text = library.source
        $head.appendChild script
      else if library.type == 'css'
        style = document.createElement "style"
        style.innerHTML = library.source
        $head.appendChild style

  #
  # Starring custom XHR wrapper!
  #
  # @private
  #
  _ajax: (method, url, callback) ->
    if window.XMLHttpRequest
      xhr = new XMLHttpRequest
    else
      xhr = new ActiveXObject 'Microsoft.XMLHTTP'

    xhr.onreadystatechange = -> callback?(xhr) if xhr.readyState > 3
    xhr.open method, url, 1
    xhr.send()

    xhr