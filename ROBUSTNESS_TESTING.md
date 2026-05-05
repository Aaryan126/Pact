# Robustness Testing

"Solid detection" is not a single benchmark, it's robustness across the conditions real students study in. A detector that works in your office at 2pm on a sunny Tuesday is not solid.

This document defines the robustness matrix and how to verify the engine handles each axis.

## The robustness matrix

Test the engine across the cross-product of these axes. You don't need every combination, but you need coverage of each axis.

### Lighting
- Bright daylight, window in front of user
- Bright daylight, window behind user (strong backlight, hard case)
- Bright daylight, window to the side (uneven lighting)
- Evening, room overhead light only
- Evening, desk lamp only (single point source, dramatic shadows)
- Late night, only laptop screen as light source (very dim, blue-shifted)
- Mixed: lamp + screen + ambient

The hardest cases are backlit and screen-only-lit. Face Mesh can struggle with detection or landmark accuracy in these.

### Camera angle and distance
- Laptop on desk, eye level, ~50cm distance (ideal)
- Laptop on desk, below eye level (camera looks up, common with low desks)
- Laptop on lap, camera tilted up (very common for students, hardest angle)
- Laptop on stand, camera above eye level
- Distance: 30cm (close), 50cm (normal), 80cm (far)

### Subject appearance
- With and without glasses (glasses can disrupt eye landmarks)
- With and without facial hair
- Different hair styles (long hair occluding face, hood up, hat, etc.)
- Different skin tones (MediaPipe is generally good here but verify)
- Headphones (some over-ear headphones occlude the face partially)
- Mask (rare but worth a sanity check)

### Behavior edge cases
- Reading a physical textbook on desk (head down, eyes moving, but focused)
- Writing on paper notebook on desk (head down, hand visible, focused)
- Hand on chin / thinking pose (face partially occluded)
- Drinking coffee (briefly raising cup occludes face)
- Stretching / leaning back (head far from camera or out of frame)
- Coughing, sneezing, yawning
- Multiple people walking past in background

### Environment
- Plain wall behind user
- Busy background (bookshelf, posters, other people moving)
- Multiple monitors (user looks left/right at second screen — should this be focused or looking_away?)

## How to test each

For each axis, do one of:

1. **Add to eval set.** Best option. Record a labeled clip in that condition and add to `eval/recordings/`. Eval runs will catch regressions.
2. **Manual smoke test.** Run the engine live in that condition, watch the state output, verify it matches reality.
3. **Synthetic test.** Use augmentation (brightness/contrast adjustments, rotations) on existing recordings to simulate some conditions cheaply.

## Known hard cases (document, don't pretend to solve)

These are inherently ambiguous and the engine will get them wrong sometimes. The product handles this via the user correction UI on the summary screen. Document them clearly:

- **Reading a physical book.** Looks identical to phone use from the camera. Mitigation: user can tag the segment as focused on the summary screen.
- **Talking to yourself while thinking.** Mouth movement without head turn. Engine may flag as talking. Probably rare enough to accept.
- **Deep thinking with eyes closed.** Indistinguishable from microsleep. Probably correct to flag, but offer correction.
- **Looking at second monitor outside the camera's view.** Looks like "away" or "looking_away" depending on angle. Document that single-monitor setups are the v1 supported configuration.
- **Wearing very dark sunglasses.** Eye state detection fails. Edge case, low priority.

## Acceptance for v1

For v1, you do not need to ace every condition. You need to:

1. Hit the eval F1 thresholds in `EVAL_METHODOLOGY.md` on a test set that includes at least: 2 lighting conditions, 2 camera angles, 1 person.
2. Document known failure modes openly in the app's onboarding or help section.
3. Provide the user correction UI as a safety net for ambiguous cases.

Robustness is an ongoing investment, not a v1 launch blocker. But you must measure it, not assume it.

## Failure logging during real use (opt-in, post-v1)

Eventually, when users tag a segment as "actually focused", that's a signal of a false positive. With consent, these corrections (just the labels and timing, never the video) become a feedback loop for finding systematic detection issues. Out of scope for v1, but design the data model so this is easy to add later.
