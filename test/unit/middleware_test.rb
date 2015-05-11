require "test/unit"
require_relative "../../lib/roger_babeljs"

class MiddlewareTest < ::Test::Unit::TestCase
  def setup
    fixture = File.read(File.dirname(__FILE__) + "/../fixtures/es6.js")

    # Always respond with the file contents in this little app
    @app = proc{[200,{},[fixture]]}

    @stack = RogerBabeljs::Middleware.new(@app)
    @request = Rack::MockRequest.new(@stack)
  end

  def test_without_matching_url_should_not_trigger_middleware
    response = @request.get('/')
    assert response.body.include?("let a")
  end

  def test_with_matching_url_should_trigger_middleware
    response = @request.get('/javascripts/src/test.js')
    assert response.body.include?("var a")
  end
end