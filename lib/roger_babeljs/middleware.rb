require "singleton"
require "time"
require_relative "cache/memory"

module RogerBabeljs
  # Middleware
  #
  # Middleware to do on the fly BabelJS conversion
  class Middleware
    attr_reader :cache

    # @option options [Array] :match Array of regexp's to match URLS
    #   that should run through babel. Default: [/\A\/javascripts\/src\/.*\.js\Z/]
    # @option options [Array] :skip Array of regexp's to skip URLS
    #   that should NOT run through babel. Skip is stronger than match. Default: []
    # @option options [Hash] :babel_options Options to pass to babel.
    # @option options [false, :memory] :cache EXPERIMENTAL! Define if RogerBabel should use a cache.
    #   Default: false
    def initialize(app, options = {})
      @app = app

      @options = {
        match: [%r{\A/javascripts/src/.*\.js\Z}],
        skip: [],
        babel_options: {},
        cache: false
      }.update(options)

      if @options[:cache] && @options[:cache] == :memory
        @cache = Cache::Memory.instance
      else
        @cache = nil
      end
    end

    def call(env)
      # See if any URL matches PATH_INFO
      if url_matches?(env["PATH_INFO"])
        # Assign it to local variable here; sometimes middleware changes the environment
        # deeper down the callstack.
        url = env["PATH_INFO"]
        status, headers, body = @app.call(env)

        # Only pass the content to babel if the request was successful
        if status == 200
          get_or_build_response(url, body, status, headers).finish
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
      @options[:match].find { |regex| regex.match(path) } &&
        @options[:skip].find { |regex| regex.match(path) }.nil?
    end

    # Try to get the response from cache or build and cache it if we don't get
    # a cache hit.
    #
    # If there is no cache configured it will just pass everything along to build_response
    def get_or_build_response(url, body, status, headers)
      if cache && headers["Last-Modified"]
        mtime = get_mtime(headers["Last-Modified"])

        if mtime
          code = cache.get(url, mtime)
          if code
            ::Rack::Response.new(code, status, headers)
          else
            response = build_response(url, body, status, headers)
            cache.set(url, response.body, mtime)
            response
          end
        end
      else
        build_response(url, body, status, headers)
      end
    end

    def get_mtime(mtime)
      Time.parse(mtime) if !mtime.nil? && !mtime.empty?
    rescue ArgumentError
      nil
    end

    def build_response(url, body, status, headers)
      if body.is_a?(String)
        code = body
      else
        # We must use "each" here as we cannot know what we get form the chain.
        # Rack defines that it must at least have an .each method.
        code = []
        body.each { |f| code << f }
        code = code.join
      end

      es5 = convert_es6_to_es5(code, url)
      ::Rack::Response.new(es5, status, headers)
    rescue ExecJS::RuntimeError => err
      ::Rack::Response.new(err.message, 500, headers)
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
