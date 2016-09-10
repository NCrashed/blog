---
title: HSOC evaluation for live profiling server
image: images/haskell-logo.png
description: The summer was awesome, I finally pushed the HSOC "Live profiling and performance monitoring server" project to consistent state. Almost all features are implemented and changes to GHC are submitted to Phabricator.
---

The summer was awesome, I finally pushed the [Haskell Summer of Code 2016](https://summer.haskell.org/) "Live profiling and performance monitoring server" [project](/posts/2016-06-12-hsoc-acceptance.html) to consistent state. Most features are implemented and changes to GHC are submitted to Phabricator.

## Live profile server

[The server](https://github.com/NCrashed/live-profile-server) is a web based application to view and manage eventlogs that are uploaded manually or received from [live-profile-monitor](https://github.com/NCrashed/live-profile-monitor).

At the moment server is able to produce [ghc-events-analyze](http://www.well-typed.com/blog/86/) like diagrams:

![](/images/screen-fib-bined.png#center-sized)

The server backend is based on [servant](http://haskell-servant.readthedocs.io/en/stable/) library and the frontend is developed with GHCJS and [reflex-dom](https://github.com/reflex-frp/reflex-platform). Diagrams are rendered with [diagrams-reflex](https://hackage.haskell.org/package/diagrams-reflex) backend for [diagrams](http://projects.haskell.org/diagrams/) library.

The current implementation transforms an event log into relational model and stores in
SQL database. Then the model is queried by [esqueleto](https://hackage.haskell.org/package/esqueleto) queries to collect statistics for diagrams render. That is a little too slow 
and I plan to use memory cache for future implementation diagrams that are updated on fly
with fresh events from a live monitor.

You can try it alive at [debug server](http://liveprofile.teaspotstudio.ru). With guest
permissions one can view logs and diagrams and also upload eventlog files. Sorry for
poor performance of rendering it can take up to 7 minutes to render a diagram for 50 MB
log. I have ideas how to fix this, but I haven't implemented them yet.

## RTS patches

I finally submitted the RTS changes to [Trac](https://ghc.haskell.org/trac/ghc/ticket/12582) and [Phabricator](https://phabricator.haskell.org/D2522). The diff is pending for a review.

## Summary 

Which goals are achieved at the moment:

* [RTS side](https://phabricator.haskell.org/D2522):

  1. Redirecting eventlog to user specified file descriptor.

  2. Storing eventlog in memory and ability to retreive the events chunks from it.

  3. Dynamic resizing of eventlog buffers.

* [Monitor](https://github.com/NCrashed/live-profile-monitor), implementation details are described [here](/posts/2016-06-22-hsoc-rts.html) and [here](/posts/2016-07-20-hsoc-monitoring-library.html):
  
  1. Connection to profiled application via small "leech" library and FIFO pipe. 

  2. Collecting eventlog state and sending it by request of remote profiling tool.

  3. Transmission protocol between the monitor and remote tool. Robust implementation
  is TCP one, but the protocol designed to be used with datagrams for UDP future
  support.

* [Server](https://github.com/NCrashed/live-profile-server):

  1. Getting logs by live connection to remote monitor or by manual upload via
  web frontend.

  2. Management of connections and sessions.

  3. ghc-events-analyze like graphics.

  4. Authorisation system.

As byproduct I extracted some packages that can be useful on its own:

* [aeson-injector](http://hackage.haskell.org/package/aeson-injector) - simple way to wrap
into a JSON object plain value or insert a JSON field to your data.

* [servant-auth-token-api](http://hackage.haskell.org/package/servant-auth-token-api) - token based authorisation API for servant.

* [servant-auth-token](http://hackage.haskell.org/package/servant-auth-token) - an implementation of `servant-auth-token-api` that can be easily embeded in your server.

## servant-rest-derive

Also I had some fun with [vinyl](http://hackage.haskell.org/package/vinyl), servant and persistent. I got a automatic deriving of RESTful API and server from only a vinyl record definition. It looks like:

``` haskell
-- | Connection to remote application
type Connection = FieldRec '[
    '("name", Text)
  , '("host", Text)
  , '("port", Word)
  , '("lastUsed", Maybe UTCTime)
  ]

instance Named Connection where 
  getName _ = "Connection"

-- | Correspoinding patch record
$(declareVinylPatch ''Connection)

-- | API about connections to remote Haskell applications that we profile
type ConnectionAPI = "connection" :> RESTFull Connection "connection"
```

This was for API deriving, and server side deriving (with full support of Persistent library):

``` haskell
connectionServer :: ServerT ConnectionAPI App 
connectionServer = restServer (Proxy :: Proxy '[ 'GET, 'POST, 'PUT, 'PATCH, 'DELETE]) 
  (Proxy :: Proxy Connection) (Proxy :: Proxy "connection")
  (Proxy :: Proxy App)
```

I am going to make a several blog post about the type level magic that was used to implement this and also to publish independent packages for automatic deriving of 
REST servers. At the moment the packages are located at the `live-profile-server` repo, see [servant-rest-derive](https://github.com/NCrashed/live-profile-server/tree/master/servant-rest-derive) and [servant-rest-derive-server](https://github.com/NCrashed/live-profile-server/tree/master/servant-rest-derive-server) subfolders.

## Future work

I am not going to drop the project, as it is far from state that is helpful at production. Following features are next to do:

* Render diagrams on the fly. The current implementation renders a particular snapshot of log and is too slow to be used for live data.

* Add thread scope like diagrams and heap statistics diagrams that can be extracted from eventlog.

* Multi user mode for server. An user should be able to upload private logs that are not shown to other users.

* Options for 24/7 monitoring of servers, that requires specific settings, for instance, when to drop old events from DB or which types of statistics to save for long term. 

