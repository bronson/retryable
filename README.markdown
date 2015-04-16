# Retryable

Automatically retry a code block when an exception occurs.

[![Build Status](https://api.travis-ci.org/bronson/retryable.png?branch=master)](http://travis-ci.org/bronson/retryable)
[![Dependency Status](https://gemnasium.com/bronson/retryable.png)](https://gemnasium.com/bronson/retryable)

    require "retryable"
    include Retryable

    retryable(:tries => 3, :on => IOError) do
        read_flaky_sector
    end

This calls read_flaky_sector and returns the result.
If an IOError was raised, it tries the call again,
and one more time (for 3 tries total) before giving up
and letting the most recent exception propagate upward.


## Install

* Bundler: `gem "retryable", :git => "git://github.com/bronson/retryable.git"`

You must include the module before using it.
This allows unrelated libraries to set up their
own defaults without any chance of conflicts.

    class MyUtility
      include Retryable
      retryable_options :tries => 10
    end


## Options

Retryable uses these defaults:

* :tries => 2  # try the call once, then retry once
* :on => StandardError
* :sleep => 1
* :matching => /.\*/
* :detect_nesting => false
* :logger => lambda { |task,retries,error| ... }  # only logs if you specify a :task
* :task => nil

You can pass custom settings every time you call the retryable command,
or call retryable_options to change the default settings:

    retryable_options :tries => 5, :sleep => 20
    retryable { catch_dog }


## Sleeping

By default Retryable waits for one second between retries.  You can change this,
even providing your own exponential backoff scheme.

    retryable(:sleep => 0) { }                    # no pause between retries
    retryable(:sleep => 10) { }                   # sleep ten seconds between retries
    retryable(:sleep => lambda { |n| 4**n }) { }  # sleep 1, 4, 16, etc. each try
    retryable(:sleep => nil) { }                  # don't even call sleep


## Disabling

If you set :tries to 0 then your block won't be called at all.
You can use this to temporarialy disable all your retryable blocks:

    retryable_options :tries => 0


## Exceptions

Retryable retries any exception that inherits from StandardError.
This catches most runtime errors (IOError, floating point) but lets most
more catastrophic errors (missing method, nil reference) pass through without
being retried.

Generally you only want to retry a few specific errors anyway:

    :retryable(:on => [IOError, RangeError]) { ... }

You can certainly retry everything but, be warned, this is probably not what you want!
Do you really want to retry method missing, out of memory, and a whole range of other
errors that can't be fixed by trying again?

    :retryable(:on => Exception) { ... }

More on Ruby exceptions:

 * <http://blog.nicksieger.com/articles/2006/09/06/rubys-exception-hierarchy>
 * <http://www.zenspider.com/Languages/Ruby/QuickRef.html#34>

You can also retry based on the exception message:

    :retryable(:matching => /export/) { ... }


## Block Parameters

Your block is called with two optional parameters: the number of tries until now,
and the most recent exception.

    retryable { |retries, exception|
      puts "try #{retries} failed: #{exception}" if retries > 0
      pick_up_soap
    }


## Logging

retryable offers a little logging assistance if you specify a task.

    retryable(:task => 'pick up sticks') { raise IOError }

Prints:

    pick up sticks
    pick up sticks RETRY 1 because IOError

Use :logger to change the log message or destination:

    retryable_options :logger => lambda { |task,retries,error|
        logger.error "retry #{task} #{retries}: #{error}" if retries > 0
    }


## Nesting

Accidentally nesting callbacks can be a real problem.  What you thought was
a 6 minute maximum delay could end up being 36 minutes or worse.
Nesting detection is off by default but it's easy to turn on.

    retryable(:detect_nesting => true) {
      retryable { thread_needle }   # thread_needle will never be called
    }

When Retryable detects a nested call it throws a Retryable::NestedException.
This is not a StandardError, so it's not retried by default, and the error
will propagate out.


## Examples

Open an URL, retry up to two more times when an `OpenURI::HTTPError` occurs.

    require "retryable"
    require "open-uri"

    include Retryable

    retryable(:tries => 3, :on => OpenURI::HTTPError) do
      xml = open("http://google.com/").read
    end

Print the default settings:

    ruby -r ./lib/retryable.rb -e "include Retryable; puts Retryable.retryable_options.inspect"


## Alternatives

* NodeJS: <https://github.com/tim-kos/node-retry>


## License

MIT or public domain, your choice.


## History

The story until now...

* 2008 [Cheah Chu Yeow](https://github.com/chuyeow/try)
  wrote retryable as a monkeypatch to Kernel and wrote a
  [blog post](http://blog.codefront.net/2008/01/14/retrying-code-blocks-in-ruby-on-exceptions-whatever/).
* 2009 [Carlo Zottmann](https://github.com/carlo/retryable)
  converted it to a gem and made it a separate method.
* 2010 [Songkick](https://github.com/songkick/retryable)
  converted it to a module and added :matching and :sleep.
* 2011 [Scott Bronson](https://github.com/bronson/retryable)
  rebased it back onto Chu's repo, added flexible sleep and nesting detection.

