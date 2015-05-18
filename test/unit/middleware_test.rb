require "test/unit"
require_relative "../../lib/roger_babeljs"

# MiddlewareTest
class MiddlewareTest < ::Test::Unit::TestCase
  def build_stack(file, options = {})
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/" + file)

    # Always respond with the file contents in this little app
    app = proc { [200, {}, [fixture]] }

    stack = RogerBabeljs::Middleware.new(app, options)
    Rack::MockRequest.new(stack)
  end

  def test_without_matching_url_should_not_trigger_middleware
    response = build_stack("es6.js").get("/")
    assert response.body.include?("let a")
    assert_equal response.status, 200
  end

  def test_with_matching_url_should_trigger_middleware
    response = build_stack("es6.js").get("/javascripts/src/test.js")
    assert response.body.include?("var a")
    assert_equal response.status, 200
  end

  def test_skip_should_not_match
    stack = build_stack("es6.js", match: [/.*\.js\Z/], skip: [/fail\.js\Z/])
    assert stack.get("/match.js").body.include?("var a")
    assert stack.get("/fail.js").body.include?("let a")
  end

  def test_custom_babel_options
    babel_options = {
      "loose" => ["es6.modules"],
      "modules" => "amd"
    }
    stack = build_stack("es6.js", babel_options: babel_options)
    response_with_options = stack.get("/javascripts/src/test.js")
    assert response_with_options.body.include?("define(")
    assert_equal response_with_options.status, 200
  end

  def test_default_babel_options
    response_without_options = build_stack("es6.js").get("/javascripts/src/test.js")
    assert !response_without_options.body.include?("define(")
    assert_equal response_without_options.status, 200
  end

  def test_broken_es6
    response = build_stack("es6-broken.js").get("/javascripts/src/broken.js")
    assert response.body.include?("SyntaxError")
    assert_equal response.status, 500
  end
end
