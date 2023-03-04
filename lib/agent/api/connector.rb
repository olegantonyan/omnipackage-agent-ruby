# frozen_string_literal: true

require 'agent/api/client'
require 'agent/api/scheduler'
require 'agent/utils/timed_queue'

module Agent
  module Api
    class Connector
      attr_reader :scheduler

      def initialize(apihost, apikey)
        @logger = ::Agent.logger
        @queue = ::Agent::TimedQueue.new
        @scheduler = ::Agent::Api::Scheduler.new(logger, queue)
        @thread = ::Thread.new do
          mainloop(::Agent::Api::Client.new(apihost, apikey))
        end
      end

      def join
        thread.join
      end

      private

      attr_reader :thread, :logger, :queue

      def mainloop(client) # rubocop: disable Metrics/MethodLength
        loop do
          response = client.call(scheduler.state.to_hash)

          if response.ok?
            scheduler.call(response.payload)
          else
            logger.error("connector error: #{response.error_message}")
          end

          case queue.pop(response.next_poll_after)
          when 'quit'
            break
          end
        end
      end
    end
  end
end