module Retryable
  def retryable_options options=nil
    @retryable_options = options = nil if options == :reset
    @retryable_options ||= {
      :tries     => 1,
      :on        => StandardError,
      :sleep     => 1,
      :matching  => /.*/,
    }

    @retryable_options.merge!(options) if options
    @retryable_options
  end

  def retryable options = {}, &block
    opts = retryable_options.merge options
    return nil if opts[:tries] < 1

    previous_exception = nil
    retry_exceptions = [opts[:on]].flatten
    retries = 0

    begin
      return yield retries, previous_exception
    rescue *retry_exceptions => exception
      raise unless exception.message =~ opts[:matching]
      raise if retries >= opts[:tries]

      previous_exception = exception
      sleep opts[:sleep]
      retries += 1
      retry
    end
  end
end
