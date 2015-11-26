require 'dat-worker-pool/worker'

module DatTCP

  module Worker

    def self.included(klass)
      klass.class_eval do
        include DatWorkerPool::Worker

      end
    end

    module TestHelpers

      def self.included(klass)
        klass.class_eval do
          include DatWorkerPool::Worker::TestHelpers
        end
      end

    end

  end

end
