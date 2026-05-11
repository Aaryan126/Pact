# Dataset Research

Last updated: 2026-05-06

## Summary

Public datasets can help test individual CV signals, but they will not replace a Clarity-specific eval set. The product states are study-session states, while most public data is driver monitoring, gaze estimation, lip reading, or active speaker detection.

Use public datasets for:

- Head pose sanity checks: pitch/yaw/roll behavior.
- Eye closure threshold tests.
- Mouth movement / speaking-vs-not-speaking tests.
- Robustness checks across lighting, glasses, ethnicity, and camera angle.

Still record our own short webcam clips for:

- `focused`
- `away`
- `looking_down` as study-head-down, not phone detection
- `talking` in a laptop/desk context
- `eyes_closed`

## Best Candidates

| Dataset | Useful For | Fit | Caveats |
|---|---|---|---|
| NTHU Driver Drowsiness Detection Dataset | `eyes_closed`, yawning, nodding, talking/laughing, looking sideways | High for drowsiness and robustness | Driver setup, IR video, access requires license request by email. |
| YawDD | Mouth movement, talking/singing vs normal/yawning | Useful for `talking` false positives | Driver setup, not laptop study context. |
| BIWI Kinect Head Pose | Head pose validation for pitch/yaw/roll | Useful for pose sanity | Kinect/depth setup, non-commercial research license. |
| MPIIFaceGaze / MPIIGaze | Laptop-use gaze/head pose variation | Strong contextual fit for gaze/head pose | Gaze dataset, not behavior/state dataset. |
| Columbia Gaze | Eye gaze and head-pose combinations | Useful for separating head pose from gaze | Still images, controlled lab setup. |
| AVA Active Speaker | Speaking/not-speaking labels | Good for active speaker research | Uses audio-visual labels; v1 Clarity intentionally avoids audio. |
| GRID Audio-Visual Speech Corpus | Controlled talking mouth movement | Useful MAR/lip movement baseline | Lab speech, not natural distraction. |
| LRW | Lip movement in the wild | Large talking-mouth corpus | Short word clips; mostly useful if we later build a visual speech model. |
| DMD Driver Monitoring Dataset | Drowsiness, talking, phone, gaze/head pose | Broadest driver-monitoring match | Very large; driver context; access workflow required. |
| Distracted Driver Dataset / 100-Driver | Phone and passenger distraction | Useful for “what phone use looks like” | Not aligned with webcam-only laptop camera; mostly posture/driver images. |

## Recommended Use

1. **Immediate:** keep manual webcam preview testing for `talking`.
2. **Near-term:** record 5-10 short Clarity clips locally and label them.
3. **Then:** use public datasets only to stress-test specific thresholds:
   - BIWI or MPIIFaceGaze for pitch/yaw/roll.
   - NTHU or CEW-like eye datasets for eye closure.
   - YawDD, GRID, or AVA Active Speaker for mouth movement.
4. **Do not train a model yet.** The current v1 engine is rule-based and should stay explainable until the eval says rules are insufficient.

## Source Notes

- NTHU DDD: NTHU CV Lab describes 36 subjects, day/night conditions, glasses/sunglasses, yawning, slow blink, falling asleep, laughing, talking, and looking sideways. Access requires filling the license agreement and emailing the lab. Source: https://cv.cs.nthu.edu.tw/php/callforpaper/datasets/DDD/
- YawDD: University of Ottawa yawning dataset with driver videos under natural lighting, including normal, talking/singing, and yawning conditions. Source: https://qualinet.github.io/databases/video/yawdd_a_yawning_detection_dataset/
- BIWI Kinect Head Pose: ETH Zurich dataset with over 15K images of 20 people and ground-truth 3D head pose. Source: https://vision.ee.ethz.ch/datsets.html
- MPIIFaceGaze / MPIIGaze: laptop-use gaze dataset with 213,659 full-face images from 15 users collected during everyday laptop use. Source: https://collaborative-ai.org/research/datasets/MPIIFaceGaze/
- Columbia Gaze: 5,880 images of 56 people with controlled gaze directions and head poses, non-commercial use. Source: https://www.cs.columbia.edu/CAVE/databases/columbia_gaze/
- AVA Active Speaker: about 3.65M human-labeled frames over 38.5 hours with face-track speaking/not-speaking labels. Source: https://research.google/pubs/ava-activespeaker-an-audio-visual-dataset-for-active-speaker-detection/
- GRID: 34 talkers, 1,000 spoken sentences per talker, audiovisual recordings and word alignments. Source: https://zenodo.org/records/3625687
- LRW: Oxford-BBC Lip Reading in the Wild, 500 word classes with hundreds of speakers and short utterance clips. Source: https://www.robots.ox.ac.uk/~vgg/data/lip_reading/lrw1.html
- DMD: Vicomtech Driver Monitoring Dataset with face/body/hands cameras and labels for distraction, drowsiness, talking on phone, talking, drinking, eye state, microsleeps, yawning, gaze/head pose, and more. Source: https://github.com/Vicomtech/DMD-Driver-Monitoring-Dataset
- Distracted Driver Dataset: 14,478 frames from 44 participants across safe driving, phone, texting, drinking, passenger talking, and other classes. Source: https://heshameraqi.github.io/distraction_detection
- 100-Driver: more than 470K images from 100 drivers over 79 hours, 4 cameras, 5 vehicles. Source: https://100-driver.github.io/

## Practical Recommendation

For Clarity, the highest-value dataset is still our own. Public data should answer narrow questions like “is EAR threshold stable across faces?” or “does MAR variance distinguish talking from neutral mouth movement?” It should not be used as proof that the app can measure study focus accurately.
