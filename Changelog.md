# Changes

## Next (Unreleased)

Bugfix: Fix leaky bucket leak calculation
See [PR description](https://github.com/zendesk/prop/pull/34)

## 2.3.0

Bugfix: Fix concurrency bug
See [PR description](https://github.com/zendesk/prop/pull/33)

## 2.2.5

Add a reader method for `cache` to top level `Prop` module
Added compatibility with Rails 5.2

## 2.2.4

Added compatibility with Rails 5.1

## 2.2.3

Remove Fixnum and replace with Integer per 2.4.1 Deprecations
Supported Rubies: 2.4.1, 2.3.4, 2.2.7

## 2.2.2

Bugfix: Fix underflow error in decrement method
See: [PR Description](https://github.com/zendesk/prop/pull/26)

## 2.2.1

Support decrement method for LeakyBucketStrategy
Support multiple rails versions (3.2, 4.1, 4.2, 5.0)

## 2.2.0 (also 2.1.3)

Support decrement method for IntervalStrategy

Decrement can be used to for example throttle before an expensive action and then give quota back when some condition is met.
`:decrement` is only supported for `IntervalStrategy` for now

In case of api failures we want to decrement the rate limit:

`Prop.throttle!(:api_counts, request.remote_ip, decrement: 1)`

## 2.1.2

Freeze string literals
