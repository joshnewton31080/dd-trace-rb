# frozen_string_literal: true

# typed: false

require 'datadog/tracing/contrib/patcher'
require 'datadog/tracing/contrib/sneakers/integration'
require 'datadog/tracing/contrib/sneakers/tracer'

module Datadog
  module Tracing
    module Contrib
      module Sneakers
        # Patcher enables patching of 'sneakers' module.
        module Patcher
          include Contrib::Patcher

          module_function

          def target_version
            Integration.version
          end

          def patch
            ::Sneakers.middleware.use(Sneakers::Tracer, nil)
          end
        end
      end
    end
  end
end
