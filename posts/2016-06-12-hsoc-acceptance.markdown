---
title: Live profiling and performance monitoring server 
image: images/haskell-logo.png
description: HSOC has suddenly received additional funding and my project of improving GHC event logging experience now is among the chosen ones. The post contains the full proposal description and info about mentors. 
---

I was quite disappointed when my project wasn't announced as accepted for [Haskell Summer of Code 2016](https://www.reddit.com/r/haskell/comments/4kp6zg/summer_of_haskell_2016_accepted_projects/). But HSOC got additional funding and I participate now, yay! The following part of the post contains full text of my proposal revised. I've lost some time, but I am sure, that the incoming summer will be productive. 


## What is the goal of your project?

The goal of this project is to improve runtime analysis of the haskell programs by combining existing eventlog framework, heap profiling tools and new features of the GHC runtime. The scope of this work includes:

* extending runtime system to support writing eventlog and profile information into unix sockets or TCP descriptors;

* the evaluation and extension of the tools necessary to make use of this. 


## Can you give some more detailed design of what precisely you intend to achieve?

The intended work could be split in three parts: RTS improvements, development of a monitoring server, extending of supporting libraries.

1. RTS improvements should allow to stream profiling and event log data to the external sources. Primary targets are such sinks are TCP or UNIX domain sockets, but implementation should be general enough to allow user to add his own. This could be achieved by creating callback system that will allow user to add hooks on different events, like buffer is full, or request certain events like sync events to happen. This design allow to keep RTS as simple and as generic as possible. All complex logic will be implemented on library level. Other improvements may include runtime tuning of the logging options, such as:

  a. Switching eventlog and profiling on and of during in runtime;

  b. Tweaking parameters like per-cap buffer size;

  c. Enabling and disabling concrete subsystems (GC, user events, etc.)

Implementation of the TCP and UNIX domain socket proxy as an example of the library code. This application should be production quality and could be used as a reasonable default for users who want to have event tracing. 

2. Supporting libraries that are needed to implement monitoring server includes utilities and tools for end-user integration. This will likely require additions and reworking existing tools, such as hp2any, threadscope, or ghc-events. Also library that uses new RTS features to implement transferring eventlog data via TCP and UNIX domain sockets. Finer grained profiling tools can be built on top of the enumerated tasks, if they fit within the scope of the project.

3. Monitoring server is a end-user application that can be used to monitor and present all information provided by the new runtime monitoring framework inside RTS. This server will be implemented in haskell and will be able to connect to running program either by socket or file. (This monitoring can be run in compatibility mode and incrementally read information from eventlog and profile files, so it will be possible to use it even for code that was compiled by older GHC that doe not have new framework). Monitor server displays reports, logs and diagrams based on log data (that are activity of each HEC, threads, user events, heap profile, and calculate some stats, example is duration between 2 user events (see ghc-events-analyse)).


## Do you have a mentor in mind? If so, whom? Have you already spoken with them about this?

Official mentor: Austin Seipp aka [thoughtpolice](https://github.com/thoughtpolice)

Comentor: Alexander Vershilov aka [qnikst](http://qnikst.github.io/) 


## What deliverables do you think are reasonable targets? Can you outline an approximate schedule of milestones?

_Features that are marked by [optional] could be sacrificed if some severe issues appear. It doesn’t mean that I am not going to implement them to the end of hsoc, but they are not critical for practical application of the work._

1. RTS features, optional features actually taken from unfinished work in 2014 of Karolis Velicka:
  
  * Defining new hook type that is called when eventlog buffer is full. This is the minimum viable product, and has a good power to weight ratio for the basic cases. 

  * _[optional]_ Allow turning event logging on/off as a whole at runtime.

  * _[optional]_ Allow turning on/off individual classes of events at runtime.

  * _[optional]_ Allow emitting "synchronisation" events, mainly to be used when switching eventlog on/off or redirecting the output to a new sink, or just from time to time to let monitoring apps get a full tracking state.

  * _[optional]_ Allow active flushing of the eventlog buffers. Normally the eventlog data is only flushed when a per-cap buffer is full. This can be a long time if one cap is very active while another is not.

2. Haskell support libraries for:

  * Incremental parser of eventlog and heap profile. Actually the parser is already done by Karolis Velicka and hp2any author Patai Gergely. So task is to reuse existing pieces of code. Important note is that parser should accept incomplete eventlog files, for instance, from crashed programs.

  * Library that uses stated RTS hook features to enable transferring eventlog datum via TCP and UNIX domain sockets. 

  * _[optional]_ Utilities for wrapping execution of expressions with user defined markers. That tagged expressions are displayed at the monitoring server with time bounds when they were evaluated.

3. Haskell monitoring server, ThreadScope like web-application:

  * Display activity on each Haskell Execution Context;

  * An activity profile indicates the rough utilization of the HECs;

  * View the rate at which "par sparks" are created and evaluated during the program, and the size of the spark queue on each HEC.

  * Display heap usage diagrams from heap profiling info loaded from file

  * Connect to RTS TCP/UNIX sockets or load data from files.

  * _[optional]_ Control RTS from web-application.

  * _[optional]_ Display activity on each Haskell thread.

  * _[optional]_ Management of saved profiles. Comparing a profile with previous runs.

4. Investigation activity:

  * Investigate interference between eventlog and heap profile.

  * Explore profitability of socket-based RTS services. Does FIFO hack performs better? Does live streaming skew picture of performance too much?

  * Investigate new statistics that can be extracted from event log and future direction of development of RTS profiling.

Milestones:

1. Investigation of previous methods. I am going to reimplement an age-old hack [item 9 in references] using a FIFO for the eventlog, and use it as prototype of live streaming. This would also be a nice fallback mode for older users, until patches are available in GHC.

2. Monitoring server development. I want to implement haskell web-server (yesod or servant based) for streaming profile data into browser client implemented with modern web technologies. The main goal is to provide a cross-platform profiling tool. At the point I could reuse http://heap.ezyang.com/ widget for heap profiling and improve it. There’s luckily a lot of code that can probably be reused in many places (including ThreadScope itself).

3. Implementation of RTS features. I am going to implement the necessary streaming features in the runtime, and see how it compares to hack-based approach and scales for real usage. Implementation of further features (such as dynamic on/off switches) will require more work, but the minimum necessary features are  certainly achievable. As the RTS is complex and has many concerns, this design process will need to begin early.

4. Monitoring server improvement. After these are in place, modifying tools like the monitor to use sockets and future improvements is much more viable. Also at the stage I am going to make some usability improvements (saved profiles for instance).

5. Investigation activity. Within the milestone I am going to find out answers to questions stated in investigation activity section and questions that will raise during previous milestones.

6. Enclosing milestone. Final stage is deploying web-server, making wiki-pages, cleaning documentation, final community negotiations. Although documentation developing should be shared over the course of the process, I distinguish the stage as the documentation would become major part of my activity at the end of development, as this will be necessary for the wider community to take advantage. 

## In what ways will this project benefit the wider Haskell community?

* Currently there is no good story for runtime application profiling. Eventlog and heap metrics can be used only if application successfully exits, this makes it unusable in case if long running application should be inspected in runtime.  The primary example of the library that can be used for runtime monitoring is EKG, it provides a solid ground for monitoring and is general enough to over different backends and new metrics. But it’s primary target is user defined metrics. This this framework will provide a working approach for lifetime monitoring of the RTS events.

* Implemented RTS features will allow users to implement their own backends for live monitoring as design choices for proposed monitoring server cannot satisfy all range of users. The following eventlog backends for live streaming could be implemented in future work: UDP, ZeroMQ, DSS, circular buffer file.

* Proposed monitoring server is portable and ‘plug and work’ solution for majority of Haskell community. The server provides all in one tool for analysis of profile information.

* One can deploy community public server that simplifies profiling to compilation of program with certain flags and connecting it to the public server. Corporate local servers are possible too.


## Related work and references

1. [Original Trac ticket](https://ghc.haskell.org/trac/summer-of-code/ticket/1658).

2. [ThreadScope](https://wiki.haskell.org/ThreadScope) - is a tool for performance profiling of parallel Haskell programs.

3. [ghc-events-analyse](http://www.well-typed.com/blog/86/) - awesome tool with per thread analysis.

4. [hp2html](https://hackage.haskell.org/package/hp2html) - a tool for converting GHC heap-profiles to HTML.

5. [hp2any](https://wiki.haskell.org/Hp2any) - a set of tools to deal with heap profiles.

6. [GHC event log](https://ghc.haskell.org/trac/ghc/wiki/EventLog)  general info.

7. Karolis Velicka original [wiki page](https://ghc.haskell.org/trac/ghc/wiki/EventLog/LiveMonitoring).

8. [ghc-events](https://hackage.haskell.org/package/ghc-events) - library for parsing eventlog.

9. [how to trap](http://man7.org/linux/man-pages/man7/fifo.7.html ) current implementation of eventlog (FIFO hack) - 

10. [ekg](http://hackage.haskell.org/package/ekg-0.4.0.9) - related project for remote monitoring.