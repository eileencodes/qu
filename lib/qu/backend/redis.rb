require 'redis-namespace'
require 'simple_uuid'

module Qu
  module Backend
    class Redis < Base
      attr_accessor :namespace

      def initialize
        self.namespace = :qu
      end

      def push(payload)
        payload.id = SimpleUUID::UUID.new.to_guid
        body = dump('klass' => payload.klass.to_s, 'args' => payload.args)
        connection.multi do |multi|
          multi.set("job:#{payload.id}", body)
          multi.rpush("queue:#{payload.queue}", payload.id)
        end
        payload
      end

      def pop(queue_name)
        if id = connection.lpop("queue:#{queue_name}")
          if data = connection.get("job:#{id}")
            data = load(data)
            return Payload.new(:id => id, :klass => data['klass'], :args => data['args'])
          end
        end
      end

      def abort(payload)
        connection.rpush("queue:#{payload.queue}", payload.id)
      end

      def complete(payload)
        connection.del("job:#{payload.id}")
      end

      def size(queue = 'default')
        connection.llen("queue:#{queue}")
      end

      def clear(queue = 'default')
        while id = connection.lpop("queue:#{queue}")
          connection.del("job:#{id}")
        end
      end

      def connection
        @connection ||= ::Redis::Namespace.new(namespace, :redis => ::Redis.connect(:url => ENV['REDISTOGO_URL'] || ENV['BOXEN_REDIS_URL']))
      end
    end
  end
end
