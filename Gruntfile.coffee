module.exports = (grunt) ->

  grunt.loadNpmTasks 'grunt-contrib-connect'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-jasmine'
  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-uglify'
  grunt.loadNpmTasks 'grunt-coffeelint'
  grunt.loadNpmTasks 'grunt-release'

  grunt.initConfig
    watch:
      source:
        files: ['src/**/*.coffee']
        tasks: ['coffee:source']
      specs:
        files: ['spec/**/*.coffee']
        tasks: ['coffee:specs']

    coffee:
      source:
        files:
          'lib/loada.js': 'src/loada.coffee'

      specs:
        expand: true
        src: ["spec/**/*.coffee"]
        dest: '.grunt'
        ext: '.js'

    coffeelint:
      source:
        files:
          src: ['src/**/*.coffee']
        options:
          'max_line_length':
            level: 'ignore'

    connect:
      specs:
        options:
          port: 8888

    release:
      options:
        bump: false
        add: false
        commit: false
        push: false

    jasmine:
      core:
        options:
          host: 'http://localhost:8888/'
          keepRunner: true
          outfile: "index.html"
          vendor: 'components/sinonjs/sinon.js'
          specs: ".grunt/spec/**/*_spec.js"
          helpers: ".grunt/spec/helpers/**/*.js"
        src: "lib/loada.js"

    uglify:
      core:
        files:
          'lib/loada.min.js': 'lib/loada.js'

  grunt.registerTask 'default', ['coffee', 'connect', 'jasmine:core:build', 'watch']

  grunt.registerTask 'test', ['coffee', 'connect', 'coffeelint', 'jasmine', 'bowerize']

  grunt.registerTask 'publish', ['test', 'publish:ensureCommits', 'release']

  grunt.registerTask 'bowerize', ->
    bower = require './bower.json'
    meta  = require './package.json'

    bower.version = meta.version
    require('fs').writeFileSync 'bower.json', JSON.stringify(bower, null, 2)

  grunt.registerTask 'publish:ensureCommits', ->
    complete = @async()

    grunt.util.spawn {cmd: "git", args: ["status", "--porcelain" ]}, (error, result) ->
      if !!error || result.stdout.length > 0
        console.log ""
        console.log "Uncommited changes found. Please commit prior to release or use `--force`.".bold
        console.log ""
        complete false
      else
        complete true