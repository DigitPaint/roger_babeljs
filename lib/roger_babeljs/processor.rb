require "roger/release"

module RogerBabeljs
  # Processor
  #
  # Processor for transpiling ES6 -> ES5 code with Babel during release
  class Processor < Roger::Release::Processors::Base
    # @param [Hash] options Options as described below
    #
    # @option options [Array] :match An array of shell globs, defaults to ["javascripts/**/*.scss"]
    # @option options [Array] :skip An array of regexps which will be skipped, defaults to []
    def call(release, options = {})
      options = {
        match: ["javascripts/**/*.js"],
        skip: []
      }.update(options)

      match = options.delete(:match)
      skip = options.delete(:skip)

      files = release.get_files(match, skip)
      files.each do |f|
        release.log(self, "Transpiling #{f}")

        content = File.read(f)
        File.open(f, "w") do |fh|
          fh.write Babel::Transpiler.transform(content)["code"]
        end
      end
    end
  end
end

Roger::Release::Processors.register(:babeljs, RogerBabeljs::Processor)
