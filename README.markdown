# Kernel#retryable

## Description

Runs a code block, and retries it when an exception occurs. It's great when
working with flakey webservices (for example).

It's configured using two optional parameters --`:tries` and `:on`--, and
runs the passed block. Should an exception occur, it'll retry for (n-1) times.

Should the number of retries be reached without success, the last exception
will be returned/raised.


## Examples

1. Open an URL, retry up to two times when an `OpenURI::HTTPError` occurs.

    retryable( :tries => 3, :on => OpenURI:HTTPError ) do
      xml = open( xml_url ).read
    end

2. Do _something_, retry up to four times for either `ArgumentError` or
   `TimeoutError` exceptions.

    retryable( :tries => 5, :on => [ ArgumentError, TimeoutError ] ) do
      # some crazy code
    end


## Defaults

    :tries => 1, :on => Exception
    

## Installation

First, [make sure GitHub is a gem source](http://gems.github.com/). Then, install the gem:

    sudo gem install carlo-retryable
    

