# Scribe System

might also rename this as ToolBox and think of it more of a utility to bring in to get things going and I can swap out as I need.

TODO Move this into its own Package

This package is focused on abstracting away weird OS abstractions. But as that is a pretty broad statement, the main goal of this target/package is to keep as many `#if` directives out of the main modules as I would like to abstract all those away over time.


## Other idea

// https://forums.swift.org/t/swift-nio-for-serial-ports-other-devices/67018
// This sorta got me started Need to debug and figure out why nothing is getting read
/*
TODO handle shutdown Signal and clean up
TODO how do we pass the input as an async stream of bytes to Scribe
Is this even a good idea? I think yes because introduces a client that I
can hopefully use to send data to Scribe as a Server. I think this will
also take some experimenation on how I wanna recieve data, send data, when
I start up does a server and client start? Do I check for a running server?
Sorta like vs Code or Tmux.

I wanna have my client running connect to different servers, local or remote and view data and start and run programs. So the programs and config should be for the Server side part and the client will be dump and handle different input types and render feedback.

When doing local client server IPC how does that work? Maybe look into Distributed Actors?

How does detaching process so that it stays running after I disconnect
https://en.wikipedia.org/wiki/SIGHUP

How do we compose EventLoop Grounds?
- I think I need one for input
- and one to send output to the server and receive output from the server

How does Async await mix in?

I think this will be a good idea if nothing else understanding how NIO actually
works

How should SSH fit int.

Short term goal.
have Terminal client that spawns a LocalServer and talks over SSH.
Just use two local host for now. You can figure out the distributed actor stuff
later?

Controller Input should also live in this Package to some degree. I controller
is a Screen less client. ya how do you split input and output?

Not right now focus on getting scribe more functional then complicated.
*/

serach for `func idk`
```swift
idk()
```
