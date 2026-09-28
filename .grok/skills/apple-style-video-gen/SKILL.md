---
name: apple-style-video-gen
description: Produce a bright single-hero "Apple ad" product film from HTML with HyperFrames — white-room stage, large clean display type, one hero object per shot, long-tail eases, narration and music under the picture. Use when the user asks for an Apple-style or keynote-grade product video, launch film, or app promo, or wants a dark draft rebuilt bright and clean.
---

# Apple-style video gen

A treatment overlay for product films built with HyperFrames. It fixes the look and the shot discipline; the authoring contract, timing attributes, and render commands belong to `/hyperframes-core` and `/hyperframes-cli`, and the workflow routing belongs to `/product-launch-video`. Read those first, then apply this.

Derived from the TranslateCat launch film. See `LAUNCH-FILM-PROMPTS.md` at the repo root for the brief and prompts that produced it, and check the film itself before trusting any written plan.

## The bar

Every frame must survive side-by-side comparison with an Apple product commercial. One idea per shot, one hero object, huge confident type, generous empty space, and nothing decorative. If a frame needs a second idea, it is two frames.

## Stage and palette

- **Bright by default.** A near-white room: `#fcfaf2` cream or a clean white. Type is near-black ink (`#05060a`), never pure `#000`. Soft radial light pools bloom behind the hero object at roughly 6–10% opacity, with a soft contact shadow under it. Low-strength film grain is allowed.
- **One accent, used sparingly.** A single key word per frame may take a slow gradient sweep in the accent color. Body copy never carries it.
- **Brand colors live inside the product's screens.** The app's own greens and creams appear only within the device UI, not on the stage.
- **A dark stage is a deliberate choice, not a default.** When the brief is dark, or the brand is dark, confirm it before building. A dark first draft is the most common reason this treatment gets rejected and re-rendered.
- **Liquid Glass** for any surface that must exist (feature cards, logo plates): translucent blur, a 1px inner highlight on the top edge, large continuous corner radius. No hard borders and no stacked drop shadows.

## Type

- Display: SF Pro Display at weight 500–600 with negative tracking, sentence case, centered or left-aligned on a clean grid. Size by role, not by fitting the text.
- Chrome: SF Mono, uppercase, tracked out, for tiny eyebrow labels such as `IPHONE DUO` or `LIVE`. At most one per frame.
- Never more than about seven words on screen at once. Nothing important in the bottom ~17% of the frame.

## Motion

- Long-tail settles — `power3` or `expo`. Smooth over springy. The one springy element the film owns should be the mascot or a playful object.
- Type enters as a soft rise: a small translateY with opacity, plus a touch of blur clearing. Never a slide in from off-screen.
- The hero object moves with weight: slow camera orbits, a fold opening on one long ease.
- **Every piece enters on its spoken cue.** Nothing appears before the narration names it, and the back half of each frame keeps developing.
- Deliberate held frames are part of the language — a final lockup and a closing end card land and go still.

## Negative list

No purple or blue "AI" gradients, no bokeh particles, no confetti, no neon, no emoji, no stock icons that aren't SF-Symbol-like line glyphs, no browser chrome, no cursor.

Two failure modes to watch for: the slideshow failure, where each frame dumps its contents then freezes; and the screensaver failure, where everything drifts independently. Neither reads as motion.

## Pipeline

1. **Brief.** Fix message, audience, length, aspect, destination, and voice before authoring. One sentence of message, not a paragraph.
2. **Storyboard** before any HTML: per frame, the scene, its duration, the transition in, the narration line, the focal element, and a scene-by-scene beat list timed against the voiceover. Keep the negative list and the motion grammar in the storyboard header so frames inherit them.
3. **Script** separately from the storyboard, one narration line per frame, with intended delivery.
4. **Assets last, and only what a frame actually needs.** If the film needs stills or footage that does not exist, generate them in the style of an Apple product commercial: photorealistic, cinematic, 16:9, shallow depth of field, with negative space reserved where type will land, and explicitly no text, no logos, and no competing objects. Narration: name the voice and the tone explicitly and list the exact lines. Music: ask for a restrained underscore that leaves room for the voice.
5. **Frames**, then `npm run check`, then render. Fix errors before showing anyone the film.
6. **Show the film before publishing.** Review catches treatment problems that lint cannot.

## Pre-render self-check

- Does any frame hold two ideas, or a second hero object?
- Is the stage bright, with the accent used at most once per frame?
- Does every element enter on its spoken cue, with the back half still developing?
- Any element inside the bottom 17% band?
- Any item from the negative list on screen?
- Does the type ramp read as roles, not as sized-to-fit text?

## Known trap

Written plans drift from the delivered film. In the TranslateCat project the storyboard still describes a near-black stage after the film was revised to the bright treatment and rendered. Treat the rendered frames as the source of truth and re-read the storyboard against them before reusing either.
