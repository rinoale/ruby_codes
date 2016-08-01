module Overwatch
  module Matching
    module Map
      def self.included(base)
        puts 'overwatch map included'
      end

      def lobby
        puts 'this is public lobby'
      end

      private

      def hanamura
        puts 'this is private map, hanamura'
      end
    end
  end
end

module Hos
  module Matching
    module Map
      def self.included(base)
        puts 'hos map included'
      end
    end
  end
end


include Overwatch::Matching::Map

lobby

hanamura

self.class.hanamura
