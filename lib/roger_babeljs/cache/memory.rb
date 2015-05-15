module RogerBabeljs
  module Cache
    # The RogerBabeljs::Cache::Memory is a simple memory cache
    class Memory
      attr_reader :cache

      def initialize
        @cache = {}
      end

      # Set data with Key and Mtime
      def set(key, value, mtime)
        @cache[key] = {
          value: value,
          mtime: mtime
        }
      end

      # Get data with key, will return
      # nil and invalidate cache if the passed mtime > stored mtime
      def get(key, mtime)
        return nil unless @cache.key?(key)

        if @cache[key][:mtime] >= mtime
          @cache[key][:value]
        else
          delete(key)
          nil
        end
      end

      def delete(key)
        @cache.delete(key)
      end
    end
  end
end
