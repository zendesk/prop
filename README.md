
# Prop [![Build Status](https://secure.travis-ci.org/zendesk/prop.png)](http://travis-ci.org/zendesk/prop)

Prop is a simple gem for rate limiting requests of any kind. It allows you to configure hooks for registering certain actions, such that you can define thresholds, register usage and finally act on exceptions once thresholds get exceeded.

Prop uses an interval to define a window of time using simple div arithmetic. This means that it's a worst-case throttle that will allow up to two times the specified requests within the specified interval.

To get going with Prop, you first define the read and write operations. These define how you write a registered request and how to read the number of requests for a given action. For example, do something like the below in a Rails initializer:

```ruby
Prop.read do |key|
  Rails.cache.read(key)
end

Prop.write do |key, value|
  Rails.cache.write(key, value)
end
```

You can choose to rely on whatever you'd like to use for transient storage. Prop does not do any sort of clean up of its key space, so you would have to implement that manually should you be using anything but an LRU cache like memcached.

## Setting a Callback

You can define an optional callback that is invoked when a rate limit is reached. In a Rails application you could use such a handler to add notification support:

```ruby
Prop.before_throttle do |handle, key, threshold, interval|
  ActiveSupport::Notifications.instrument('throttle.prop', handle: handle, key: key, threshold: threshold, interval: interval)
end
```

## Defining thresholds

Once the read and write operations are defined, you can optionally define thresholds. If, for example, you want to have a threshold on accepted emails per hour from a given user, you could define a threshold and interval (in seconds) for this like so:

```ruby
Prop.configure(:mails_per_hour, :threshold => 100, :interval => 1.hour, :description => "Mail rate limit exceeded")
```

The `:mails_per_hour` in the above is called the "handle". You can now put the throttle to work with these values, by passing the handle to the respective methods in Prop:

```ruby
# Throws Prop::RateLimitExceededError if the threshold/interval has been reached
Prop.throttle!(:mails_per_hour)

# Prop can be used to guard a block of code
Prop.throttle!(:expensive_request) { calculator.something_very_hard }

# Returns true if the threshold/interval has been reached
Prop.throttled?(:mails_per_hour)

# Sets the throttle "count" to 0
Prop.reset(:mails_per_hour)

# Returns the value of this throttle, usually a count, but see below for more
Prop.count(:mails_per_hour)
```

Prop will raise a `RuntimeError` if you attempt to operate on an undefined handle.

## Scoping a throttle

In many cases you will want to tie a specific key to a defined throttle. For example, you can scope the throttling to a specific sender rather than running a global "mails per hour" throttle:

```ruby
Prop.throttle!(:mails_per_hour, mail.from)
Prop.throttled?(:mails_per_hour, mail.from)
Prop.reset(:mails_per_hour, mail.from)
Prop.query(:mails_per_hour, mail.from)
```

The throttle scope can also be an array of values, e.g.:

```ruby
Prop.throttle!(:mails_per_hour, [ account.id, mail.from ])
```

## Error handling

If the throttle! method gets called more than "threshold" times within "interval in seconds" for a given handle and key combination, Prop throws a `Prop::RateLimited` error which is a subclass of `StandardError`. This exception contains a "handle" reference and a "description" if specified during the configuration. The handle allows you to rescue `Prop::RateLimited` and differentiate action depending on the handle. For example, in Rails you can use this in e.g. `ApplicationController`:

```ruby
rescue_from Prop::RateLimited do |e|
  if e.handle == :authorization_attempt
    render :status => :forbidden, :message => I18n.t(e.description)
  elsif ...

  end
end
```

### Using the Middleware

Prop ships with a built-in Rack middleware that you can use to do all the exception handling. When a `Prop::RateLimited` error is caught, it will build an HTTP [429 Too Many Requests](http://tools.ietf.org/html/draft-nottingham-http-new-status-02#section-4) response and set the following headers:

    Retry-After: 32
    Content-Type: text/plain
    Content-Length: 72

Where `Retry-After` is the number of seconds the client has to wait before retrying this end point. The body of this response is whatever description Prop has configured for the throttle that got violated, or a default string if there's none configured.

If you wish to do manual error messaging in these cases, you can define an error handler in your Prop configuration. Here's how the default error handler looks - you use anything that responds to `.call` and takes the environment and a `RateLimited` instance as argument:

```ruby
error_handler = Proc.new do |env, error|
  body    = error.description || "This action has been rate limited"
  headers = { "Content-Type" => "text/plain", "Content-Length" => body.size, "Retry-After" => error.retry_after }

  [ 429, headers, [ body ]]
end

ActionController::Dispatcher.middleware.insert_before(ActionController::ParamsParser, :error_handler => error_handler)
```

An alternative to this, is to extend `Prop::Middleware` and override the `render_response(env, error)` method.

## Disabling Prop

In case you need to perform e.g. a manual bulk operation:

```ruby
Prop.disabled do
  # No throttles will be tested here
end
```

## Threshold settings

You can chose to override the threshold for a given key:

```ruby
Prop.throttle!(:mails_per_hour, mail.from, :threshold => current_account.mail_throttle_threshold)
```

When the threshold are invoked without argument, the key is nil and as such a scope of its own, i.e. these are equivalent:

```ruby
Prop.throttle!(:mails_per_hour)
Prop.throttle!(:mails_per_hour, nil)
```

The default (and smallest possible) increment is 1, you can set that to any integer value using :increment which is handy for building time based throttles:

```ruby
Prop.setup(:execute_time, :threshold => 10, :interval => 1.minute)
Prop.throttle!(:execute_time, account.id, :increment => (Benchmark.realtime { execute }).to_i)
```

## License

Copyright 2013 Zendesk

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
