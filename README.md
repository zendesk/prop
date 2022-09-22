
# Prop ![Build status](https://github.com/zendesk/prop/workflows/ci/badge.svg)

A gem to rate limit requests/actions of any kind.<br/>
Define thresholds, register usage and finally act on exceptions once thresholds get exceeded.

Prop supports two limiting strategies:

* Basic strategy (default): Prop will use an interval to define a window of time using simple div arithmetic. 
This means that it's a worst-case throttle that will allow up to two times the specified requests within the specified interval.
* Leaky bucket strategy: Prop also supports the [Leaky Bucket](https://en.wikipedia.org/wiki/Leaky_bucket) algorithm, 
which is similar to the basic strategy but also supports bursts up to a specified threshold.

To store values, prop needs a cache:

```ruby
# config/initializers/prop.rb
Prop.cache = Rails.cache # needs read/write/increment methods
```

When using the interval strategy, prop sets a key expiry to its interval.  Because the leaky bucket strategy does not set a ttl, it is best to use memcached or similar for all prop caching, not redis.

## Setting a Callback

You can define an optional callback that is invoked when a rate limit is reached. In a Rails application you 
could use such a handler to add notification support:

```ruby
Prop.before_throttle do |handle, key, threshold, interval|
  ActiveSupport::Notifications.instrument('throttle.prop', handle: handle, key: key, threshold: threshold, interval: interval)
end
```

## Defining thresholds

Example: Limit on accepted emails per hour from a given user, by defining a threshold and interval (in seconds):

```ruby
Prop.configure(:mails_per_hour, threshold: 100, interval: 1.hour, description: "Mail rate limit exceeded")

# Block requests by setting threshold to 0
Prop.configure(:mails_per_hour, threshold: 0, interval: 1.hour, description: "All mail is blocked")
```

```ruby
# Throws Prop::RateLimitExceededError if the threshold/interval has been reached
Prop.throttle!(:mails_per_hour)

# Prop can be used to guard a block of code
Prop.throttle!(:expensive_request) { calculator.something_very_hard }

# Returns true if the threshold/interval has been reached
Prop.throttled?(:mails_per_hour)

# Sets the throttle count to 0
Prop.reset(:mails_per_hour)

# Returns the value of this throttle, usually a count, but see below for more
Prop.count(:mails_per_hour)
```

Prop will raise a `KeyError` if you attempt to operate on an undefined handle.

## Scoping a throttle

Example: scope the throttling to a specific sender rather than running a global "mails per hour" throttle:

```ruby
Prop.throttle!(:mails_per_hour, mail.from)
Prop.throttled?(:mails_per_hour, mail.from)
Prop.reset(:mails_per_hour, mail.from)
Prop.query(:mails_per_hour, mail.from)
```

The throttle scope can also be an array of values:

```ruby
Prop.throttle!(:mails_per_hour, [ account.id, mail.from ])
```

## Error handling

If the threshold for a given handle and key combination is exceeded, Prop throws a `Prop::RateLimited`. 
This exception contains a "handle" reference and a "description" if specified during the configuration. 
The handle allows you to rescue `Prop::RateLimited` and differentiate action depending on the handle. 
For example, in Rails you can use this in e.g. `ApplicationController`:

```ruby
rescue_from Prop::RateLimited do |e|
  if e.handle == :authorization_attempt
    render status: :forbidden, message: I18n.t(e.description)
  elsif ...

  end
end
```

### Using the Middleware

Prop ships with a built-in Rack middleware that you can use to do all the exception handling. 
When a `Prop::RateLimited` error is caught, it will build an HTTP 
[429 Too Many Requests](http://tools.ietf.org/html/draft-nottingham-http-new-status-02#section-4) 
response and set the following headers:

    Retry-After: 32
    Content-Type: text/plain
    Content-Length: 72

Where `Retry-After` is the number of seconds the client has to wait before retrying this end point. 
The body of this response is whatever description Prop has configured for the throttle that got violated, 
or a default string if there's none configured.

If you wish to do manual error messaging in these cases, you can define an error handler in your Prop configuration. 
Here's how the default error handler looks - you use anything that responds to `.call` and 
takes the environment and a `RateLimited` instance as argument:

```ruby
error_handler = Proc.new do |env, error|
  body    = error.description || "This action has been rate limited"
  headers = { "Content-Type" => "text/plain", "Content-Length" => body.size, "Retry-After" => error.retry_after }

  [ 429, headers, [ body ]]
end

ActionController::Dispatcher.middleware.insert_before(ActionController::ParamsParser, error_handler: error_handler)
```

An alternative to this, is to extend `Prop::Middleware` and override the `render_response(env, error)` method.

## Disabling Prop

In case you need to perform e.g. a manual bulk operation:

```ruby
Prop.disabled do
  # No throttles will be tested here
end
```

## Overriding threshold

You can chose to override the threshold for a given key:

```ruby
Prop.throttle!(:mails_per_hour, mail.from, threshold: current_account.mail_throttle_threshold)
```

When `throttle` is invoked without argument, the key is nil and as such a scope of its own, i.e. these are equivalent:

```ruby
Prop.throttle!(:mails_per_hour)
Prop.throttle!(:mails_per_hour, nil)
```

The default (and smallest possible) increment is 1, you can set that to any integer value using 
`:increment` which is handy for building time based throttles:

```ruby
Prop.configure(:execute_time, threshold: 10, interval: 1.minute)
Prop.throttle!(:execute_time, account.id, increment: (Benchmark.realtime { execute }).to_i)
```

Decrement can be used to for example throttle before an expensive action and then give quota back when some condition is met.

```ruby
Prop.throttle!(:api_counts, request.remote_ip, decrement: 1)
```

## Optional configuration

You can add optional configuration to a prop and retrieve it using `Prop.configurations[:foo]`:

```ruby
Prop.configure(:api_query, threshold: 10, interval: 1.minute, category: :api)
Prop.configure(:api_insert, threshold: 50, interval: 1.minute, category: :api)
Prop.configure(:password_failure, threshold: 5, interval: 1.minute, category: :auth)
```

```
Prop.configurations[:api_query][:category]
```

You can use `Prop::RateLimited#config` to distinguish between errors:

```ruby
rescue Prop::RateLimited => e
  case e.config[:category]
  when :api
    raise APIRateLimit
  when :auth
    raise AuthFailure
  ...
end
```

## First throttled

You can opt to be notified when the throttle is breached for the first time.<br/>
This can be used to send notifications on breaches but prevent spam on multiple throttle breaches.

```Ruby
Prop.configure(:mails_per_hour, threshold: 100, interval: 1.hour, first_throttled: true)

throttled = Prop.throttle(:mails_per_hour, user.id, increment: 60)
if throttled
  if throttled == :first_throttled
    ApplicationMailer.spammer_warning(user).deliver_now
  end
  Rails.logger.warn("Not sending emails")
else
  send_emails
end

# return values of throttle are: false, :first_throttled, true

Prop.first_throttled(:mails_per_hour, 1, increment: 60) # -> false
Prop.first_throttled(:mails_per_hour, 1, increment: 60) # -> :first_throttled
Prop.first_throttled(:mails_per_hour, 1, increment: 60) # -> true

# can also be accesses on `Prop::RateLimited` exceptions as `.first_throttled` 
```

## Using Leaky Bucket Algorithm

You can add two additional configurations: `:strategy` and `:burst_rate` to use the 
[leaky bucket algorithm](https://en.wikipedia.org/wiki/Leaky_bucket). 
Prop will handle the details after configured, and you don't have to specify `:strategy` 
again when using `throttle`, `throttle!` or any other methods.

The leaky bucket algorithm used is "leaky bucket as a meter".

```ruby
Prop.configure(:api_request, strategy: :leaky_bucket, burst_rate: 20, threshold: 5, interval: 1.minute)
```

* `:threshold` value here would be the "leak rate" of leaky bucket algorithm.


## License

Copyright 2015 Zendesk

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, 
software distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
See the License for the specific language governing permissions and limitations under the License.
