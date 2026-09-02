# Manage persistent voices

Each voice consists of two files on the retained voices PVC:

- `<name>.wav` contains 24 kHz mono reference audio.
- `<name>.txt` contains the exact words spoken in the WAV.

The qwentts entrypoint registers every pair when the pod starts. Restart the Deployment after changing the files.

## Set the voice files

```bash
POD="$(kubectl -n ai get pod -l app.kubernetes.io/name=qwen3-tts -o jsonpath='{.items[0].metadata.name}')"
VOICE=example_voice
WAV=./example_voice.wav
TRANSCRIPT=./example_voice.txt
```

## Add or replace a voice

Copy both files under temporary names. Rename them only after both copies finish.

```bash
REMOTE_WAV="/voices/.${VOICE}.wav.$$.tmp"
REMOTE_TEXT="/voices/.${VOICE}.txt.$$.tmp"

kubectl -n ai exec "$POD" -- rm -f "$REMOTE_WAV" "$REMOTE_TEXT"
kubectl -n ai cp "$WAV" "${POD}:${REMOTE_WAV}"
kubectl -n ai cp "$TRANSCRIPT" "${POD}:${REMOTE_TEXT}"
kubectl -n ai exec "$POD" -- sh -ceu '
  test -s "$1"
  test -s "$2"
  mv "$1" "/voices/$3.wav"
  mv "$2" "/voices/$3.txt"
' sh "$REMOTE_WAV" "$REMOTE_TEXT" "$VOICE"

kubectl -n ai rollout restart deployment/qwen3-tts
kubectl -n ai rollout status deployment/qwen3-tts --timeout=10m
```

Use the same `VOICE` name to replace an existing voice.

## Delete a voice

```bash
kubectl -n ai exec "$POD" -- rm -f \
  "/voices/${VOICE}.wav" \
  "/voices/${VOICE}.txt"

kubectl -n ai rollout restart deployment/qwen3-tts
kubectl -n ai rollout status deployment/qwen3-tts --timeout=10m
```

The Polemis voice uses `polemist_v1.wav` and `polemist_v1.txt`.
