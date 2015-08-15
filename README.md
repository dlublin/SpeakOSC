# About SpeakOSC
Listens for specified speech keyphrases / dictation and outputs the results over OSC.

See video demo here: Also see video demo here: https://vimeo.com/136399791


# Features
Set custom OSC messages to be sent when key phrases detected.

Raw dictation mode for sending raw transcription strings over OSC.

Save and Open documents with lists of commands.


# Notes
Dictation only works when SpeakOSC is the active application and the dictation text field is selected.

Speech Commands work when SpeakOSC is active or in the background.


# About the code
This app uses the standard OS X NSSpeechRecognizer to listen for specified commands.

It also enables the OS X dictation mode to capture raw text input.

It uses [VVOpenSource / VVOSC](https://github.com/mrRay/vvopensource) for OSC output.
