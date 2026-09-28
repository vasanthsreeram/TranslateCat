# Prompts that produced the launch film

The 45-second TranslateCat launch film in `videos/translatecat-launch/renders/video.mp4` (not tracked by git) was built with HyperFrames during one session on 2026-09-26. This file records the prompts that drove it: the requests typed into the agent, in order, and the asset prompts the agent then issued for image, voice, and music generation.

Source conversation: Bitrig Claude session `0e8c08af-78e8-4dd3-8a05-913cae16947f`, project `~/Documents/bitrighackyc/TranslateCat`.

## Requests

1. The film grew out of the presentation: *"you konw this app that we are buidlign I need to make slides for this can you make a slides explaing all the featuers that it has and th eui and so on use images from online to make ti look nice use the apple galss ui so that the slides will demo the whoel tranaslation in the translate cat adn we can have the anliatio f ta cat waslkign asndtuff it shodu be in a html page open it in local host it shoudl have scroll animation"*

2. A real iPhone Duo, not a generic phone: *"the phoen that its using is nto the duo make su reot use the duo get indperison from this website https://www.apple.com/iphone-duo/ it shodul look like a native iphoen app"*

3. Folded-mode demo with live typing: *"make it like 3d ans stuff show it off in liek the folded mode adn how ti will display the view for the other person and have the chars type in when its done you know ?"*

4. *"there shdoul be 3d ktis workign proerly"*

5. The film itself: *"I think you need to make it video can you us the hyperframes and stuff adn then make this with teh voice using the grok oauth for the tts and then use the codex gpt image for the images if you need more images adn sutff ok ? make it into a very premium video and also mention that this was built with bitrigs and monetisatoin is handled by revenue cat"*

6. Voice route correction: *"noep use the grook oauth cli fro the voice thingy its alr signedin"*

7. The quality bar: *"make it look like an apple ad ok thats teh min standard"*

8. *"once done open the video for me"*

9. *"can I see the vidoe ?"*

10. *"how many more fremas left ?"*

11. *"is it done ?"*

12. *"can you put the video in the website ?"*

13. *"if the video is done let me open it first ?"*

14. Feedback after the first render, with a screenshot attached: *"bruh wtf is this make teh vidoe like a proepr apple adevet so it shdount[ be dark it shoudl be white themee like apple"*

15. Feedback on substance, with a screenshot attached: *"it shoudl have the 3d thingy that you made adn then it shoudl show the diff vieqs and hten have the text explaing it you know what I mean then have it be more efficiently"*

16. *"give me the detials for these"*

## Asset prompts the agent issued

**Images** (subagent, `assets/generated/prompt_history.jsonl`):

> Use your image_gen tool to create TWO photorealistic, cinematic 16:9 landscape images in the style of an Apple iPhone TV commercial, and save them as files in `assets/generated` with exactly these base names (keep the extension the tool returns, png or jpg):
> 1) hook-street — Dusk in a narrow European old-town street (Lisbon-like), warm amber shop lights, a traveler seen from behind, slightly out of focus, looking toward a café where a local waiter stands. Very shallow depth of field, rich bokeh, deep shadows, moody, lots of dark negative space in the center-left for large white headline text. No text, no signs with readable words, no logos, no phones.
> 2) cafe-table — Close, low-angle shot of a small round marble café table at golden hour, two espresso cups, two people's hands resting on either side (a traveler and a local), soft window light, extremely shallow depth of field, the center of the table left EMPTY and softly lit. No text, no logos, no phones.
> Reply only with the two absolute saved paths.

**Voice** (subagent, `~/.grok/sessions/%2Fprivate%2Ftmp%2Fgrok-tts/prompt_history.jsonl`):

> Using your own signed-in xAI/Grok account, generate spoken audio with xAI's text-to-speech using the SAME voice you used before: Orion. Tone: calm, warm, confident Apple-keynote narrator. Make one MP3 per line, saved exactly to these paths, with exactly this text (keep the punctuation, including the ellipsis pause):
> 01.mp3 : Every trip has that moment. You want to talk... but you just can't.
> 02.mp3 : Meet TranslateCat. A live interpreter, built for iPhone Duo.
> 03.mp3 : Unfold it, stand it on the table, and just talk. You see your words, on the inside.
> 04.mp3 : And they read theirs on the outside. Typed live, letter by letter. Then it listens right back.
> 05.mp3 : It knows who's speaking. It keeps clear notes of every chat. And on-device Apple Intelligence helps you find your way, in eight languages.
> 06.mp3 : Built with Bitrig. And monetisation, handled by RevenueCat.
> 07.mp3 : TranslateCat. Two screens. One conversation.
> Do not create any other files in that folder. When done, reply only with the list of saved paths, or the exact error.

**Music** (`bgm_request.json`):

> premium minimal cinematic underscore for an Apple product commercial, soft felt piano over warm pulsing synth pads, gentle rising build, hopeful and elegant, 90 bpm, no vocals

## The same prompt, tightened

> Build a roughly 45-second launch film for TranslateCat, a face-to-face translator for iPhone Duo. Open on the travel problem, then show an accurate 3D iPhone Duo unfolding into tabletop mode: my words on the inner display, the other person's translated captions typing out on the outer display, and a reply coming back. Use the app's real interface. One idea per shot, calm narration, restrained music, and on-screen text timed to the demonstration. Bright, clean, Apple-ad quality — no dark treatment. Mention that the app was built with Bitrig and monetized with RevenueCat. Storyboard and script it, generate only the assets you need, render it, and show me the film before publishing.
