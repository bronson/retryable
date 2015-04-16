begin
  # coverage is optional
  require 'simplecov'
  SimpleCov.start
rescue Exception
end

if ENV["TRAVIS"] || ENV["COVERALLS_RUN_LOCALLY"]
  require 'coveralls'
  Coveralls.wear!
end

require File.dirname(File.expand_path(__FILE__)) + '/../lib/retryable'

describe "Retryable" do
  include Retryable

  before :each do
    retryable_options :reset
  end

  def sleep n
    # each test must set its own expectation on how sleep will be called
    raise "Unexpected call to sleep!"
  end

  def should_raise e
    lambda { yield }.should raise_error e
  end

  def count_retryable *opts
    @try_count = 0
    return retryable(*opts) { |*args|
      @try_count += 1
      yield(*args)
    }
  end


  it "should not affect the return value of the block" do
    expect_any_instance_of(Object).not_to receive(:sleep)
    result = count_retryable { 'foo' }
    expect(result).to eq 'foo'
    expect(@try_count).to eq 1
  end

  it "should not affect the return value when there is a retry" do
    expect(self).to receive(:sleep).once.with(1)
    result = count_retryable { |tries, ex|
      raise StandardError if tries < 1
      'foo'
    }
    expect(result).to eq 'foo'
    expect(@try_count).to eq 2
  end

  it "passes the exception to the application" do
    expect(self).to receive(:sleep).once.with(1)
    expect {
      count_retryable { raise IOError }
    }.to raise_error(IOError)
    expect(@try_count).to eq 2
  end

  it "should not retry Exceptions by default" do
    expect {
      count_retryable { raise Exception }
    }.to raise_error(Exception)
    expect(@try_count).to eq 1
  end

  it "doesn't call the proc if :tries is 0" do
    count_retryable(:tries => 0) { raise RangeError }
    expect(@try_count).to eq 0
  end

  it "calls the proc once if :tries is 1" do
    expect {
      count_retryable(:tries => 1) { raise RangeError }
    }.to raise_error(RangeError)
    expect(@try_count).to eq 1
  end

  it "calls the proc twice if :tries is 2" do
    expect(self).to receive(:sleep).once.with(1)
    expect {
      count_retryable(:tries => 2) { raise RangeError }
    }.to raise_error(RangeError)
    expect(@try_count).to eq 2
  end

  it "retries the specified number of times" do
    expect(self).to receive(:sleep).exactly(2).times.with(1)
    expect {
      count_retryable(:tries => 3) { raise StandardError }
    }.to raise_error(StandardError)
    expect(@try_count).to eq 3
  end

  it "retries an exception that is covered by :on" do
    # FloatDomainError is a subclass of RangeError
    expect(self).to receive(:sleep).once.with(1)
    expect {
      count_retryable(:on => RangeError) { raise FloatDomainError }
    }.to raise_error(FloatDomainError)
    expect(@try_count).to eq 2
  end

  it "doesn't retry exceptions that aren't covered by :on" do
    # NameError is a sibliing of RangeError, not a subclass
    expect {
      count_retryable(:on => RangeError) { raise NameError }
    }.to raise_error(NameError)
    expect(@try_count).to eq 1
  end

  it "retries multiple exceptions that are covered by :on" do
    # FloatDomainError is a subclass of RangeError
    expect(self).to receive(:sleep).once.with(1)
    expect {
      count_retryable(:on => [IOError, RangeError, NoMethodError]) { raise FloatDomainError }
    }.to raise_error(FloatDomainError)
    expect(@try_count).to eq 2
  end

  it "doesn't retry any exception if :on is empty" do
    expect {
      count_retryable(:on => []) { raise FloatDomainError }
    }.to raise_error(FloatDomainError)
    expect(@try_count).to eq 1
  end

  it "should catch an exception that matches the regex" do
    expect(self).to receive(:sleep).once.with(1)
    count_retryable(:matching => /IO timeout/) { |c,e| raise "yo, IO timeout!" if c == 0 }
    expect(@try_count).to eq 2
  end

  it "should not catch an exception that doesn't match the regex" do
    expect {
      count_retryable(:matching => /TimeError/) { raise "yo, IO timeout!" }
    }.to raise_error(RuntimeError)
    expect(@try_count).to eq 1
  end

  it "works with all the options set" do
    expect(self).to receive(:sleep).exactly(3).times.with(0.3)
    count_retryable(:tries => 4, :on => RuntimeError, :sleep => 0.3, :matching => /IO timeout/) { |c,e| raise "my IO timeout" if c < 3 }
    expect(@try_count).to eq 4
  end

  it "works with all the options set globally" do
    expect(self).to receive(:sleep).exactly(3).times.with(0.3)
    retryable_options :tries => 4, :on => RuntimeError, :sleep => 0.3, :matching => /IO timeout/
    count_retryable { |c,e| raise "my IO timeout" if c < 3 }
    expect(@try_count).to eq 4
  end

  it "sends the previous exception to the block" do
    expect(self).to receive(:sleep).once.with(1)
    retryable { |tries, e|
      raise IOError if tries == 0         # first time through the loop
      expect(e).to be_an_instance_of IOError  # make sure second time matches the first
    }
  end

  it "accepts :tries as a global option" do
    expect(self).to receive(:sleep).exactly(3).times.with(1)
    retryable_options :tries => 4
    expect {
      count_retryable { raise RangeError }
    }.to raise_error(RangeError)
    expect(@try_count).to eq 4
  end

  it "accepts a proc for sleep" do
    [1, 4, 16, 64].each { |i|
      expect(self).to receive(:sleep).once.ordered.with(i)
    }
    retryable_options :tries => 5, :sleep => lambda { |n| 4**n }
    expect {
      retryable { raise RangeError }
    }.to raise_error(RangeError)
  end

  it "should not call sleep if :sleep is nil" do
    count_retryable(:sleep => nil) { |c,e| raise StandardError if c == 0 }
    expect(@try_count).to eq 2
  end

  it "should allow nesting by default" do
    result = retryable { retryable { 'inner' } }
    expect(result).to eq 'inner'
  end

  it "detects nesting" do
    retryable_options :detect_nesting => true
    expect {
      retryable { retryable { raise "not reached" } }
    }.to raise_error(Retryable::NestingError)

    # and make sure that the nesting flag is turned off
    result = retryable { 'foo' }
    expect(result).to eq 'foo'
  end

  it "detects nesting even if inner loop refuses" do
    expect {
      retryable(:detect_nesting => true) {
        retryable(:detect_nesting => false) { raise "not reached" }
      }
    }.to raise_error(Retryable::NestingError)
  end

  it "doesn't allow invalid options" do
    expect {
      retryable(:bad_option => 2) { raise "this is bad" }
    }.to raise_error(Retryable::InvalidOptions)
  end

  it "doesn't allow invalid global options" do
    expect {
      retryable_options :bad_option => 'bogus'
      raise "not reached"
    }.to raise_error(Retryable::InvalidOptions)
  end

  it "should automatically log" do
    task = 'frobnicating the fizlunks'
    retryable_options :sleep => nil, :logger => lambda { |t,r,e|
      expect(t).to eq task
      expect(r).to eq @try_count
      expect(e).to eq nil if r == 0
      expect(e.message).to eq "RangeError" if r > 0
    }
    expect {
      count_retryable(:task => task) { raise RangeError }
    }.to raise_error(RangeError)
  end

  it "should test the default logging" do
    task = 'setting sigmaclapper to 0'
    expect {
      # sad to mock puts but alternatives get seriously complex
      expect(STDERR).to receive(:puts).with("setting sigmaclapper to 0")
      expect(STDERR).to receive(:puts).with("setting sigmaclapper to 0 RETRY 1 because RangeError")
      count_retryable(:task => task, :sleep => nil) { raise RangeError }
    }.to raise_error(RangeError)
  end

  it "should not remember temporary options" do
    # found a bug where setting local options would affect globals
    # (forgot to dup the global hash when merging in the local opts)
    retryable_options :logger => lambda { |t,r,e| }
    expect(retryable_options[:task]).to eq nil
    retryable(:task => "TASK SET") { }
    expect(retryable_options[:task]).to eq nil
  end
end
