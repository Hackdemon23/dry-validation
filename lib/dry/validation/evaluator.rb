# frozen_string_literal: true

require 'dry/initializer'

require 'dry/validation/constants'
require 'dry/validation/failures'

module Dry
  module Validation
    # Evaluator is the execution context for rules
    #
    # Evaluators expose an API for setting failure messages and forward
    # method calls to the contracts, so that you can use your contract
    # methods within rule blocks
    #
    # @api public
    class Evaluator
      extend Dry::Initializer

      # @!attribute [r] _contract
      #   @return [Contract]
      #   @api private
      param :_contract

      # @!attribute [r] result
      #   @return [Result]
      #   @api private
      option :result

      # @!attribute [r] keys
      #   @return [Array<String, Symbol, Hash>]
      #   @api private
      option :keys

      # @!attribute [r] macros
      #   @return [Array<Symbol>]
      #   @api private
      option :macros, optional: true, default: proc { EMPTY_ARRAY.dup }

      # @!attribute [r] _context
      #   @return [Concurrent::Map]
      #   @api private
      option :_context

      # @!attribute [r] path
      #   @return [Dry::Schema::Path]
      #   @api private
      option :path, default: proc { Dry::Schema::Path[(key = keys.first) ? key : ROOT_PATH] }

      # @!attribute [r] values
      #   @return [Object]
      #   @api private
      option :values

      # @!attribute [r] block_options
      #   @return [Hash<Symbol=>Symbol>]
      #   @api private
      option :block_options, default: proc { EMPTY_HASH }

      # @return [Hash]
      attr_reader :_options

      # Initialize a new evaluator
      #
      # @api private
      def initialize(contract, **options, &block)
        super(contract, **options)

        @_options = options

        if block
          exec_opts = block_options.map { |key, value| [key, _options[value]] }.to_h
          instance_exec(**exec_opts, &block)
        end

        macros.each do |args|
          macro = macro(*args.flatten(1))
          instance_exec(**macro.extract_block_options(_options.merge(macro: macro)), &macro.block)
        end
      end

      # Get `Failures` object for the default or provided path
      #
      # @param [Symbol,String,Hash,Array<Symbol>] path
      #
      # @return [Failures]
      #
      # @see Failures#failure
      #
      # @api public
      def key(path = self.path)
        (@key ||= EMPTY_HASH.dup)[path] ||= Failures.new(path)
      end

      # Get `Failures` object for base errors
      #
      # @return [Failures]
      #
      # @see Failures#failure
      #
      # @api public
      def base
        @base ||= Failures.new
      end

      # Return aggregated failures
      #
      # @return [Array<Hash>]
      #
      # @api private
      def failures
        @failures ||= []
        @failures += @base.opts if defined?(@base)
        @failures.concat(@key.values.flat_map(&:opts)) if defined?(@key)
        @failures
      end

      # @api private
      def with(new_opts, &block)
        self.class.new(_contract, **_options, **new_opts, &block)
      end

      # Return default (first) key name
      #
      # @return [Symbol]
      #
      # @api public
      def key_name
        @key_name ||= keys.first
      end

      # Return the value found under the first specified key
      #
      # This is a convenient method that can be used in all the common cases
      # where a rule depends on just one key and you want a quick access to
      # the value
      #
      # @example
      #   rule(:age) do
      #     key.failure(:invalid) if value < 18
      #   end
      #
      # @return [Object]
      #
      # @public
      def value
        values[key_name]
      end

      # Return if the value under the default key is available
      #
      # This is useful when dealing with rules for optional keys
      #
      # @example
      #   rule(:age) do
      #     key.failure(:invalid) if key? && value < 18
      #   end
      #
      # @return [Boolean]
      #
      # @api public
      def key?
        values.key?(key_name)
      end

      # Check if there are any errors under the provided path
      #
      # @param [Symbol, String, Array] A Path-compatible spec
      #
      # @return [Boolean]
      #
      # @api public
      def error?(path)
        result.error?(path)
      end

      # @api private
      def respond_to_missing?(meth, include_private = false)
        super || _contract.respond_to?(meth, true)
      end

      private

      # Forward to the underlying contract
      #
      # @api private
      def method_missing(meth, *args, &block)
        # yes, we do want to delegate to private methods too
        if _contract.respond_to?(meth, true)
          _contract.__send__(meth, *args, &block)
        else
          super
        end
      end
    end
  end
end
