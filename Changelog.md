# Changes

## Unreleased

* Drop Ruby < 2.7
* Test with Ruby 3.2 and 3.3
* Run tests with both Active Support 7.0 and 7.1

## 2.8.0

* Specify raw when reading raw cache entries [PR](https://github.com/zendesk/prop/pull/45)

## 2.7.0

* Feature: Add threshold to Prop::RateLimited exception

## 2.6.1

* Bugfix: Set expires_in on increment and decrement

## 2.6.0

* Use interval value as the ttl when writing to cache

## 2.5.0

* Bugfix: Fix leaky bucket implementation

## 2.4.0

* Allow zero case for threshold when configure the prop
* See [PR description](https://github.com/zendesk/prop/pull/37)

## 2.3.0

* Bugfix: Fix concurrency bug
* See [PR description](https://github.com/zendesk/prop/pull/33)

## 2.2.5

* Add a reader method for `cache` to top level `Prop` module
* Added compatibility with Rails 5.2

## 2.2.4

* Added compatibility with Rails 5.1

## 2.2.3

* Remove Fixnum and replace with Integer per 2.4.1 Deprecations
* Supported Rubies: 2.4.1, 2.3.4, 2.2.7

## 2.2.2

* Bugfix: Fix underflow error in decrement method
* See: [PR Description](https://github.com/zendesk/prop/pull/26)

## 2.2.1

* Support decrement method for LeakyBucketStrategy
* Support multiple rails versions (3.2, 4.1, 4.2, 5.0)

## 2.2.0 (also 2.1.3)

* Support decrement method for IntervalStrategy

Decrement can be used to for example throttle before an expensive action and then give quota back when some condition is met.
`:decrement` is only supported for `IntervalStrategy` for now

In case of api failures we want to decrement the rate limit:

`Prop.throttle!(:api_counts, request.remote_ip, decrement: 1)`

## 2.1.2

* Freeze string literals
