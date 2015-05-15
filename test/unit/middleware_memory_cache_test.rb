require "test/unit"
require "time"
require_relative "../../lib/roger_babeljs"

# MiddlewareMemoryCacheTest
class MiddlewareMemoryCacheTest < ::Test::Unit::TestCase
  def build_stack(file, options = {})
    stack = RogerBabeljs::Middleware.new(build_app(file), options)
    [Rack::MockRequest.new(stack), stack]
  end

  def build_app(file)
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/" + file)

    proc do |env|
      headers = {}

      if env["QUERY_STRING"] && !env["QUERY_STRING"].empty?
        time = Time.parse(env["QUERY_STRING"])
        headers["Last-Modified"] = time.httpdate if time
      end

      [200, headers, [fixture]]
    end
  end

  def test_store_in_cache
    request, middleware = build_stack("es6.js", match: [/.*\.js/], cache: :memory)

    assert middleware.cache

    response = request.get("test.js?2000-01-01+12:00")
    assert response.body.include?("var a")
    assert_equal response.status, 200

    assert middleware.cache.cache.key?("/test.js")
  end

  def test_serve_from_cache
    request, middleware = build_stack("es6.js", match: [/.*\.js/], cache: :memory)
    request.get("test.js?2000-01-01+12:00")

    assert middleware.cache.cache.key?("/test.js")

    # Change the source in the cache
    middleware.cache.cache["/test.js"][:value] = "CACHE"

    response = request.get("test.js?2000-01-01+12:00")

    assert_equal response.body, "CACHE"
  end

  def test_cache_invalidation
    request, middleware = build_stack("es6.js", match: [/.*\.js/], cache: :memory)
    request.get("test.js?2000-01-01+12:00")

    # Change the source in the cache
    middleware.cache.cache["/test.js"][:value] = "CACHE"

    response = request.get("test.js?2001-01-01+12:00")

    assert response.body.include?("var a")
    assert middleware.cache.cache.key?("/test.js")
  end
end
