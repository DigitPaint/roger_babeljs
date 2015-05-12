# Roger BabelJS

Roger plugin to transpile ES6 code with BabelJS

```ruby
 gem "roger_babeljs"
```

## Use it in the server

```ruby
  mockup.serve do |server|
    server.use RogerBabeljs::Middleware, {
      match: [%r{/url/you/want/to/match/*\.js}],
      babel_options: {
        # ... Options to pass to Babel
      }
    }
  end
```

## Changes and versions

Have a look at the [CHANGELOG](CHANGELOG.md) to see what's new.

## Contributors

[View contributors](https://github.com/digitpaint/roger_babeljs/graphs/contributors)

## License

MIT License, see [LICENSE](LICENSE) for more info.
