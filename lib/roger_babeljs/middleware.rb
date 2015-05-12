
module RogerBabeljs
  # Middleware
  #
  # Middleware to do on the fly BabelJS conversion
  class Middleware
    # @option options [Array] :match Array of regexp's to match URLS
    #   that should run through babel. Default: [/\A\/javascripts\/src\/.*\.js\Z/]
    def initialize(app, options = {})
      @app = app

      @options = {
        match: [/\A\/javascripts\/src\/.*\.js\Z/]
      }.update(options)
    end

    def call(env)
      if @options[:match].find { |regex| regex.match(env["PATH_INFO"]) }
        status, headers, body = @app.call(env)

        if status == 200
          body_str = []
          body.each { |f| body_str << f }
          body_str = body_str.join

          # This is a dirty little hack to always enforce UTF8
          body_str.force_encoding("UTF-8")

          es5 = Babel::Transpiler.transform(body_str, {
            "loose" => ["es6.modules"],
            "modules" => "amd"
            })

          ::Rack::Response.new(es5["code"], status, headers).finish
        else
          [status, headers, body]
        end
      else
        @app.call(env)
      end
    end
  end
end
