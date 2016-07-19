---
title: Live profile monitor
image: images/haskell-logo.png
description: Another big chunk of work is done for my HSOC project - live-profile-monitor which transfers events to remote profiling tool.
---

Another big chunk of work is done for my [HSOC project](2016-06-12-hsoc-acceptance.html) - [live-profile-monitor](https://github.com/NCrashed/live-profile-monitor) which transfers events to remote profiling tool.

## Goals and purpose

The live profile monitor is designed for:

* Transfering eventlog from locally running application to the remote host by TCP/UDP protocols.

* Causing as little disturbance in the profiling application as possible. Also we should not bloat dependency list of user application.

* Keeping track of live RTS objects that are important for profilers and transfering the collected stats to recently connected clients (profiling tools).

## Design 

After several false starts I have finally found a design that works well to fulfill goals above:

![](/images/live-profile-monitor-data-flow.png#center)

The monitor is splitted into three parts: the leech, the server and the client. 

The leech is small library almost written in C language that you link into your application. It leeches to the RTS source of events and transfers them into interprocess pipe ([mkfifo](http://linux.die.net/man/3/mkfifo) on GNU/Linux and [named pipe](https://msdn.microsoft.com/en-us/library/windows/desktop/aa365590(v=vs.85).aspx) on Windows). The library uses `pthreads` for concurrency and depends only on `base` package. The way the leech gets events is based on chunked buffer API described in [previous blog post](2016-06-22-hsoc-rts.html).

The server is heavy Haskell application that is separated from the application being profiled. We have to parse events on the server side in order to track state of eventlog: 

* alive and stopped threads;

* capabilities and set of capabilities;

* tasks;

* environment variables and command line arguments;

* heap and GC statistics;

* RTS parameters.

As I hold in mind UDP transport layer the events are serialised into datagram protocol that also includes service messages and special statistics messages. Although the UDP reliability level isn't implemented (some messages should be definitely delivered), the basement of the feature is founded.

Finally, the client library helps remote tool to understand server protocol. At the moment, the client side API looks like.

<div class="spoiler">
<input id="spoilerid_1" type="checkbox"><label for="spoilerid_1">
Client API
</label><div class="spoiler_body">
``` haskell
-- | Customisable behavior of the eventlog client
data ClientBehavior = ClientBehavior {
-- | Callback that is called when the client receives full header of the remote eventlog
  clientOnHeader :: !(Header -> IO ())  
-- | Callback that is called when the client receives a remote event
, clientOnEvent :: !(Event -> IO ()) 
-- | Callback that is called when the client receives service message from the server
, clientOnService :: !(ServiceMsg -> IO ()) 
-- | Callback that is called when the client receives dump of eventlog alive objects
, clientOnState :: !(EventlogState -> IO ()) 
}

-- | Termination mutex, all threads are stopped when the mvar is filled
type Termination = MVar ()

-- | Pair of mutex, first one is used as termination of child thread,
-- the second one is set by terminated client wich helps to hold on
-- parent thread from exiting too early.
type TerminationPair = (Termination, Termination)

-- | Connect to remote app and recieve eventlog from it.
startLiveClient :: LoggerSet -- ^ Monitor logging messages sink
  -> LiveProfileClientOpts -- ^ Options for client side
  -> TerminationPair  -- ^ Termination protocol
  -> ClientBehavior -- ^ User specified callbacks 
  -> IO ThreadId -- ^ Starts new thread that connects to remote host and 
```
</div></div>

## What is planned next

* Implement platform specific code for Windows (named pipes). At the moment only the `mkfifo` variant is ready.

* Factor out client library and protocol into separate packages to minimise amount of code that a profiling tool should depend on.

* Add some service messages for to pause/unpause eventlog, resend the RTS statistics on demand.

* Start work under web based profiling tool.
 
* Add UDP transport with reliability: implement by myself or reuse existing piece of software (possible candidate is [henet](https://hackage.haskell.org/package/henet)).