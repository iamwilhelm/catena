require_relative 'catena/scheduler'
require_relative 'catena/lang'
require 'forwardable'

module Catena
  Configuration = Struct.new(:modules)

  class << self
    extend Forwardable

    attr_reader :config

    def configure(&block)
      @config = Configuration.new if @config.nil?
      block.call(@config)
    end

    def perform(task)
      Catena::Scheduler.perform_async(task, [])
    end

    def perform_now(task)
      # Need to use Scheduler's find_callback to then run it
    end

  end

end
