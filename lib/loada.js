(function() {
  var $head,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __slice = [].slice;

  $head = document.getElementsByTagName("head")[0];

  this.Loada = (function() {
    Loada.prototype.Progress = (function() {
      function _Class(count, progressCallback) {
        this.count = count;
        this.progressCallback = progressCallback;
        this.data = {};
      }

      _Class.prototype.set = function(key, percent) {
        this.data[key] = Math.min(percent, 100.0);
        return typeof this.progressCallback === "function" ? this.progressCallback(this.total()) : void 0;
      };

      _Class.prototype.total = function() {
        var key, percent, total, _ref;
        total = 0;
        _ref = this.data;
        for (key in _ref) {
          percent = _ref[key];
          total += Math.round(percent / this.count * 100) / 100;
        }
        return total;
      };

      return _Class;

    })();

    Loada.set = function() {
      return (function(func, args, ctor) {
        ctor.prototype = func.prototype;
        var child = new ctor, result = func.apply(child, args);
        return Object(result) === result ? result : child;
      })(this, arguments, function(){});
    };

    function Loada(set, options) {
      var k, v;
      this.set = set;
      this._loadGroup = __bind(this._loadGroup, this);
      this.options = {
        prefix: 'loada',
        localStorage: true
      };
      this.requires = {
        input: [],
        set: {},
        length: 0
      };
      this.set || (this.set = '*');
      if (options) {
        for (k in options) {
          v = options[k];
          this.options[k] = v;
        }
      }
      this.key = "" + this.options.prefix + "." + this.set;
      this.setup();
    }

    Loada.prototype.setup = function() {
      if (this.options.localStorage) {
        this.storage = localStorage[this.key] || {};
        if (typeof this.storage === 'string') {
          return this.storage = JSON.parse(localStorage[this.key]);
        }
      } else {
        return this.storage = {};
      }
    };

    Loada.prototype.expire = function() {
      var byDate, byExistance, byRevision, key, library, now, _ref, _results,
        _this = this;
      if (this.options.localStorage) {
        now = new Date;
        byDate = function(library) {
          return library.expirationDate && new Date(library.expirationDate) <= now;
        };
        byExistance = function(library) {
          return !_this.requires.set[key];
        };
        byRevision = function(library) {
          return _this.requires.set[key].revision !== library.revision;
        };
        _ref = this.storage;
        _results = [];
        for (key in _ref) {
          library = _ref[key];
          if (byDate(library) || byExistance(library) || byRevision(library)) {
            _results.push(delete this.storage[key]);
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      }
    };

    Loada.prototype.save = function() {
      if (this.options.localStorage) {
        return localStorage[this.key] = JSON.stringify(this.storage);
      }
    };

    Loada.prototype.clear = function() {
      if (this.options.localStorage) {
        return delete localStorage[this.key];
      }
    };

    Loada.prototype.get = function(key) {
      var _ref;
      return (_ref = this.storage[key]) != null ? _ref.source : void 0;
    };

    Loada.prototype.require = function() {
      var libraries, library, now, _i, _len, _ref;
      libraries = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      for (_i = 0, _len = libraries.length; _i < _len; _i++) {
        library = libraries[_i];
        library.key || (library.key = library.url);
        library.type || (library.type = (_ref = library.url) != null ? _ref.split('.').pop() : void 0);
        if (library.cache == null) {
          library.cache = true;
        }
        if (library.require == null) {
          library.require = true;
        }
        if (library.expires) {
          now = new Date;
          library.expirationDate = now.setTime(now.getTime() + library.expires * 60 * 60 * 1000);
        }
        if (library.type === 'js' || library.type === 'css' || library.type === 'text') {
          this.requires.set[library.key] = library;
        } else {
          console.error("Unknown asset type for " + library.url + " – skipped");
        }
      }
      this.requires.length += libraries.length;
      return this.requires.input.push(libraries);
    };

    Loada.prototype.load = function(callbacks) {
      var loaders, progress,
        _this = this;
      callbacks || (callbacks = {});
      this.expire();
      progress = new this.Progress(this.requires.length, callbacks.progress);
      loaders = 0;
      return this._ensureSizes(callbacks.progress != null, function() {
        var group, _i, _len, _ref, _results;
        _ref = _this.requires.input;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          group = _ref[_i];
          loaders++;
          _results.push(_this._loadGroup(group.slice(0), progress, function() {
            loaders--;
            if (loaders === 0) {
              _this.save();
              return typeof callbacks.success === "function" ? callbacks.success() : void 0;
            }
          }));
        }
        return _results;
      });
    };

    Loada.prototype._ensureSizes = function(perform, callback) {
      var key, library, requests, _ref, _ref1, _results,
        _this = this;
      if (!perform) {
        _ref = this.requires.set;
        for (key in _ref) {
          library = _ref[key];
          library.size = 0;
        }
        return callback();
      }
      requests = 0;
      _ref1 = this.requires.set;
      _results = [];
      for (key in _ref1) {
        library = _ref1[key];
        _results.push((function(library) {
          if (library.size == null) {
            requests++;
            return _this._ajax('HEAD', library.url, function(xhr) {
              var size;
              requests--;
              size = xhr.getResponseHeader('Content-Length');
              if (size) {
                size = parseInt(size);
              }
              library.size = size || 0;
              if (requests === 0) {
                return callback();
              }
            });
          }
        })(library));
      }
      return _results;
    };

    Loada.prototype._loadGroup = function(group, progress, callback) {
      var library, method, results, _i, _len,
        _this = this;
      results = [];
      for (_i = 0, _len = group.length; _i < _len; _i++) {
        library = group[_i];
        if (this.storage[library.key] && library.cache) {
          if (progress != null) {
            progress.set(library.key, 100);
          }
          results.push(this.storage[library.key]);
        } else {
          method = this.options.localStorage || !library.require ? "_loadAJAX" : "_loadInline";
          this[method](library, progress, function() {
            results.push(library);
            if (results.length === group.length) {
              _this._inject(results);
              return callback();
            }
          });
        }
      }
      if (results.length === group.length) {
        this._inject(results);
        return callback();
      }
    };

    Loada.prototype._loadAJAX = function(library, progress, callback) {
      var poller, xhr,
        _this = this;
      xhr = this._ajax('GET', library.url, function(xhr) {
        if (library.cache) {
          _this.storage[library.key] = library;
        }
        library.source = xhr.responseText;
        clearInterval(poller);
        if (progress != null) {
          progress.set(library.key, 100);
        }
        return callback();
      });
      if (library.size > 0) {
        return poller = setInterval((function() {
          var percent;
          percent = Math.round(xhr.responseText.length / library.size * 100 * 100) / 100;
          return progress != null ? progress.set(library.key, percent) : void 0;
        }), 100);
      }
    };

    Loada.prototype._loadInline = function(library, progress, callback) {
      var done, proceed, script;
      if (library.type !== 'js') {
        console.error("Attempt to load something other than JS without localStorage.");
        console.error("" + library.url + " is not loaded!");
        if (progress != null) {
          progress.set(library.key, 100);
        }
        return callback();
      }
      script = document.createElement("script");
      done = false;
      proceed = function() {
        if (!done && ((this.readyState == null) || this.readyState === "loaded" || this.readyState === "complete")) {
          done = true;
          if (progress != null) {
            progress.set(library.key, 100);
          }
          if (typeof callback === "function") {
            callback();
          }
          return script.onload = script.onreadystatechange = null;
        }
      };
      script.onload = script.onreadystatechange = proceed;
      script.src = library.url;
      return $head.appendChild(script);
    };

    Loada.prototype._inject = function(libraries) {
      var library, script, style, _i, _len, _results;
      libraries = [].concat(libraries);
      _results = [];
      for (_i = 0, _len = libraries.length; _i < _len; _i++) {
        library = libraries[_i];
        if (library.require && library.source) {
          if (library.type === 'js') {
            script = document.createElement("script");
            script.defer = true;
            script.text = library.source;
            _results.push($head.appendChild(script));
          } else if (library.type === 'css') {
            style = document.createElement("style");
            style.innerHTML = library.source;
            _results.push($head.appendChild(style));
          } else {
            _results.push(void 0);
          }
        }
      }
      return _results;
    };

    Loada.prototype._ajax = function(method, url, callback) {
      var xhr;
      if (window.XMLHttpRequest) {
        xhr = new XMLHttpRequest;
      } else {
        xhr = new ActiveXObject('Microsoft.XMLHTTP');
      }
      xhr.onreadystatechange = function() {
        if (xhr.readyState > 3) {
          return typeof callback === "function" ? callback(xhr) : void 0;
        }
      };
      xhr.open(method, url, 1);
      xhr.send();
      return xhr;
    };

    return Loada;

  })();

}).call(this);
