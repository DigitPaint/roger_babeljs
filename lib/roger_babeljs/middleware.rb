require "singleton"

module RogerBabeljs
  # Middleware
  #
  # Middleware to do on the fly BabelJS conversion
  class Middleware
    # @option options [Array] :match Array of regexp's to match URLS
    #   that should run through babel. Default: [/\A\/javascripts\/src\/.*\.js\Z/]
    # @option options [Hash] :babel_options Options to pass to babel.
    def initialize(app, options = {})
      @app = app

      @options = {
        match: [%r{\A/javascripts/src/.*\.js\Z}],
        babel_options: {}
      }.update(options)
    end

    def call(env)
      # See if any URL matches PATH_INFO
      if url_matches?(env["PATH_INFO"])
        # Assign it to local variable here; sometimes middleware changes the environment
        # deeper down the callstack.
        url = env["PATH_INFO"]
        status, headers, body = @app.call(env)

        if status == 200

          # We must use "each" here as we cannot know what we get form the chain.
          # Rack defines that it must at least have an .each method.
          body_str = []
          body.each { |f| body_str << f }
          body_str = body_str.join

          build_es5_response(url, body_str, status, headers)
        else
          [status, headers, body]
        end
      else
        # Business as usual
        @app.call(env)
      end
    end

    protected

    def url_matches?(path)
      @options[:match].find { |regex| regex.match(path) }
    end

    def build_es5_response(url, code, status, headers)
      es5 = convert_es6_to_es5(code, url)
      ::Rack::Response.new(es5, status, headers).finish
    rescue ExecJS::RuntimeError => err
      ::Rack::Response.new(err.message, 500, headers).finish
    end

    def convert_es6_to_es5(code, url)
      # This is a dirty little hack to always enforce UTF8
      code = code.dup.force_encoding("UTF-8")

      options = (@options[:babel_options] || {}).dup
      options["filename"] = File.basename(url)
      options["filenameRelative"] = url

      Transformer.instance.transform(code, options)
    end
  end

  # The transformer will take care of thread safe transformation of ES6 -> ES5 code
  # using BabelJs. We need this to prevent deadlock in the V8 engine.
  class Transformer
    include Singleton

    def initialize
      @mutex = Mutex.new
    end

    def transform(code, options)
      es5 = nil
      @mutex.synchronize do
        es5 = Babel::Transpiler.transform(code, options)
      end
      es5["code"]
    end
  end
end
