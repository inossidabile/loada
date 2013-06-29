# Loada

The kickass in-browser assets (JS/CSS) loader with the support of localStorage caching and progress tracking.

Loada is here to give you control over assets loading order, parallelism, cache expiration and actual code evaluation. It works in three simple steps:

  * Specify libraries you want to load (defining an order for the dependencies)
  * Start and receive progress callback calls with current percentage during download
  * Receive success callback call and run your application – your assets are around now.

## Basic usage

Loada splits your dependencies into sets. Each set gets cached separately and keeps only
the files required at current instance. It means that if you remove one of the files from `require` 
cache will get busted on the next run keeping your **localStorage** space usage low.

Create a set to start:

```coffee
loader = Loada.set('dependencies')
```

The first argument is a name of a set (use different for different sets). Defaults to `*` if omitted.

To load an asset with the default options run

```coffee
loader.require url: '/assets/application.css'
```

To load several assets one after another (they depend on each other?) run

```coffee
loader.require {url: '/assets/jquery.js'}, {url: '/assets/application.js'}
```

And to load an external library that we don't want to cache at **localStorage** (but still want to keep at
the browser cache) run

```coffee
loader.require {url: 'http://../facebook.js', localStorage: false}
```

According to our requires, the assets will be loaded in the following order:

```
/assets/application.css

| in parallel |

/assets/jquery.js -> /assets/application.js

| in parallel |

http://../facebook.js
```

Now that we have our dependencies specified, load'em!

```coffee
loader.load
  # During downloading you will get this callback called from time to time
  progress: (percents) -> # ...

  # And this one will run as soon as all assets are around
  complete: -> # ...
```

## History

Loada is an extraction from [Joosy](http://joosy.ws) core.