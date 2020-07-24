# Zoom chat message announcer

## What is this?

Have you ever missed messages during a Zoom call? Do you wish Zoom made some noise when new messages appear?
If so, you're lucky! This is a JavaScript For Automation (JXA) script that once per second checks the contents of your Zoom chat window, and beeps and displays a notification whenever new text appears.

Note that this is only for the chat window that is available **during a Zoom call**. This is not for the call-independent chat functionality in Zoom.

### What is JXA?

It's a way to write "AppleScripts" in JavaScript. It comes included with every MacOS since 10.10. (Long before we also had AppleScript proper, but it's time to move to JavaScript)

And what is AppleScript? It's Apple's secret weapon for world domination, always was (since long before Mac OS X), and looks like it will always be. Until it gets starved to death. *Sigh*.

## How do I run it?

First you need to compile it. Afterwards you will be able to run it with a double click, like any normal app.

 1. Open Script Editor (comes included with MacOS)
 2. Make sure that it is set to work with Javascript, not Applescript:
    * Go to Script Editor - Preferences - Default Language
    * Choose "JavaScript" in there
    * Close the window.
3. Create a new window: File - New
4. Paste in there the code from the .js file in this repo
5. Save as a runnable application:
   * File - Export - Export As: Zoom chat announcer.app
   * File Format: Application
   * Options: Stay open after run handler
   * Save

At this point you have an application named "Zoom chat announcer" that you can double-click. Now you have to give it permission to interact with your system.

6. Double click the application that you just created.
   * A dialog will appear saying that it wants access to "System Events.app", which is the piece of the scripting infrastructure that allows your script to control other parts of the System.
   * Press OK to accept.
7. Another dialog will appear saying "Unable to get the chat text", saying that you need to allow use of Accessibility.
   * Press the button to open the System Preferences pane where you can allow it.
8. In that preferences pane, open the lock, look for "Zoom chat announcer" in the list of apps to the right, and check its checkbox. Close the window.

You are finished! Now you can finally double click again "Zoom chat announcer.app" and it will run.

If you don't have a Zoom chat window open it will remind you to open it. From that point on, it will notify you whenever new text appears in the chat.


## Why is this distributed in this way?
Because it's the easiest / quickest (for me ;P).

More concretely:
  * `osacompile` creates an app which somehow has problems with the System Events/Accessibility framework.
  * Committing to the repo the whole app bundle would add obscure files that are harder to trust than plain code.
  * Publishing a compiled app would need me to sign it.

## I would like it to do something different!
It's easy to customize, but feel free to open an issue and maybe I or someone else will look into it.

## Disclaimer for plausible denial
This is the longest JavaScript I have ever written, and I did so in the sucky environment of Script Editor. Works For Me (TM). Caveat emptor.
