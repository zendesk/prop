
# Prop [![Build Status](https://secure.travis-ci.org/morten/prop.png)](http://travis-ci.org/morten/prop)

Prop is a simple gem for rate limiting requests of any kind. It allows you to configure hooks for registering certain actions, such that you can define thresholds, register usage and finally act on exceptions once thresholds get exceeded.

Prop uses and interval to define a window of time using simple div arithmetic. This means that it's a worst case throttle that will allow up to 2 times the specified requests within the specified interval.

To get going with Prop you first define the read and write operations. These define how you write a registered request and how to read the number of requests for a given action. For example do something like the below in a Rails initializer:

    Prop.read do |key|
      Rails.cache.read(key)
    end

    Prop.write do |key, value|
      Rails.cache.write(key, value)
    end

You can choose to rely on whatever you'd like to use for transient storage. Prop does not do any sort of clean up of its key space, so you would have to implement that manually should you be using anything but an LRU cache like memcached.

## Defining thresholds

Once the read and write operations are defined, you can optionally define thresholds. If for example, you want to have a threshold on accepted emails per hour from a given user, you could define a threshold and interval (in seconds) for this like so:

    Prop.configure(:mails_per_hour, :threshold => 100, :interval => 1.hour, :description => "Mail rate limit exceeded")

The `:mails_per_hour` in the above is called the "handle". You can now put the throttle to work with this values, by passing the handle to the respective methods in Prop:

    # Throws Prop::RateLimitExceededError if the threshold/interval has been reached
    Prop.throttle!(:mails_per_hour)

    # Returns true if the threshold/interval has been reached
    Prop.throttled?(:mails_per_hour)

    # Sets the throttle "count" to 0
    Prop.reset(:mails_per_hour)

    # Returns the value of this throttle, usually a count, but see below for more
    Prop.count(:mails_per_hour)

Prop will raise a RuntimeError if you attempt to operate on an undefined handle.

## Scoping a throttle

In many cases you will want to tie a specific key to a defined throttle, for example you can scope the throttling to a specific sender rather than running a global "mails per hour" throttle:

    Prop.throttle!(:mails_per_hour, mail.from)
    Prop.throttled?(:mails_per_hour, mail.from)
    Prop.reset(:mails_per_hour, mail.from)
    Prop.query(:mails_per_hour, mail.from)

The throttle scope can also be an array of values, e.g.:

    Prop.throttle!(:mails_per_hour, [ account.id, mail.from ])

## Error handling

If the throttle! method gets called more than "threshold" times within "interval in seconds" for a given handle and key combination, Prop throws a Prop::RateLimited error which is a subclass of StandardError. This exception contains a "handle" reference and a "description" if specified during the configuration. The handle allows you to rescue Prop::RateLimited and differentiate action depending on the handle. For example, in Rails you can use this in e.g. ApplicationController:

    rescue_from Prop::RateLimitExceededError do |e|
      if e.handle == :authorization_attempt
        render :status => :forbidden, :message => I18n.t(e.description)
      elsif ...
    
      end
    end

## Disabling Prop

In case you need to perform e.g. a manual bulk operation:

    Prop.disabled do
      # No throttles will be tested here
    end

## Threshold settings

You can chose to override the threshold for a given key:

    Prop.throttle!(:mails_per_hour, mail.from, :threshold => current_account.mail_throttle_threshold)

When the threshold are invoked without argument, the key is nil and as such a scope of its own, i.e. these are equivalent:

    Prop.throttle!(:mails_per_hour)
    Prop.throttle!(:mails_per_hour, nil)

The default (and smallest possible) increment is 1, you can set that to any integer value using :increment which is handy for building time based throttles:

    Prop.setup(:execute_time, :threshold => 10, :interval => 1.minute)
    Prop.throttle!(:execute_time, account.id, :increment => (Benchmark.realtime { execute }).to_i)

