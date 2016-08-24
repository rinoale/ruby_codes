module Overwatch
  module Matching
    module Map
      def self.included(base)
        puts 'overwatch map included'
        base.extend ClassMethods
      end

      def lobby
        puts 'this is public lobby'
      end

      module ClassMethods
        def potion
          puts 'this is class method, object'
        end
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

# self.class.hanamura

self.class.potion

class Competition
  include Overwatch::Matching::Map
end

comp = Competition.new

Competition.potion

comp.lobby

comp.hanamura
