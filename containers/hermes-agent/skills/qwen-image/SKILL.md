---
name: qwen-image
description: Generate images with Qwen-Image, edit user reference images, or revise an image from an earlier turn through ComfyUI.
---

# Qwen image

Use the installed Hermes ComfyUI runner at `/opt/hermes/optional-skills/creative/comfyui/scripts/run_workflow.py`. The workflow files, matching parameter-mapping schemas, and prompt reference are all flat files in `/opt/managed-skills/qwen-image`. This directory is read-only. ComfyUI is already deployed; use `$COMFYUI_URL` as the runner's `--host`.

## Choose inputs and write the prompt

1. For generation without references, select `generation.api.json` and `generation.schema.json`.
2. For editing or reference-guided generation, inspect each user image with vision first. Identify the intended canvas, visible text, and the role of each reference. Put the canvas or primary subject first, then order the other references by their assigned roles. Use exactly the supplied references, never duplicate images to fill slots.
3. Select `editing-1`, `editing-2`, or `editing-3` according to that ordered reference count, using its `.api.json` and matching `.schema.json`. These workflows support one to three references. If more are supplied, ask which to use rather than silently discarding them.
4. Read `prompt-reference.md` and write the final Qwen prompt yourself. For edits, bind `<image1>` to `reference_1`, `<image2>` to `reference_2`, and `<image3>` to `reference_3`. State each supplied image's role and what changes or stays fixed. Keep a simple edit short. There is no prompt-enhancer service or node.
5. For a follow-up edit, use the intended previous downloaded output as the new first reference and inspect it again. Carry forward the user's preservation constraints. For a fresh variation without references, use generation instead. Resolve an ambiguous choice between previous outputs before submitting.

## Parameters and canvas

Both modes accept `prompt`, `seed`, `steps`, `cfg`, `aspect_ratio`, `megapixels`, `explicit_size`, `width`, and `height`. Editing also accepts `reference_resolution`, `custom_canvas`, and exactly `reference_1` through `reference_N` for its selected variant. The sidecar schema maps these names to workflow node inputs; always pass it with `--schema`.

Defaults are `seed=0`, `steps=25`, `cfg=1`, sampler `euler`, scheduler `simple`, `megapixels=1`, `aspect_ratio="1:1 (Square)"`, `explicit_size=false`, and `width=height=1024`. Leave the sampling defaults unless the user requests a change. Use `seed=-1` for a requested random variation, or an explicit integer for reproducibility.

- Generation uses `aspect_ratio` and `megapixels` by default. For a non-default ratio, read the supported `aspect_ratio` choices from `$COMFYUI_URL/object_info/ResolutionSelector` and pass the exact matching string. For exact dimensions, set `explicit_size=true`, `width`, and `height`.
- Editing defaults to `custom_canvas=false` and `reference_resolution=1024`, which follows the first reference's proportions at roughly one megapixel. This preserves its framing, not necessarily its original pixel dimensions. Size-selector parameters do not control this branch.
- For a requested custom canvas or outpainting, set `custom_canvas=true`. Then choose `aspect_ratio` and `megapixels`, or set `explicit_size=true` with `width` and `height`. Keep dimensions out of the prompt; describe the requested canvas extension in the prompt when applicable.

Use integer seeds, steps, dimensions, and reference resolutions. Explicit widths and heights must be positive multiples of 32. Keep `reference_resolution` a positive multiple of 32 up to 4096; `0` skips resolution scaling but still rounds reference dimensions to multiples of 32, and may use substantially more memory.

## Run and download

Pass the final prompt and parameter overrides directly as one JSON argument to `--args`. Use single shell quotes around the JSON; represent any apostrophe inside that quoted argument as `'\''`. JSON-escape double quotes and newlines within string values. Create a unique job directory for downloaded images.

```bash
skill_dir=/opt/managed-skills/qwen-image
mkdir -p /opt/data/cache/images
job=$(mktemp -d /opt/data/cache/images/qwen-XXXXXXXX)
python3 /opt/hermes/optional-skills/creative/comfyui/scripts/run_workflow.py \
  --workflow "$skill_dir/generation.api.json" \
  --schema "$skill_dir/generation.schema.json" \
  --args '{"prompt":"A red ceramic teapot on a pale wooden table, soft window light.","seed":42}' \
  --host "$COMFYUI_URL" \
  --output-dir "$job"
```

For a two-reference edit, set `reference_1` and `reference_2` to the inspected local file paths. Copy those real files to job-specific basenames before uploading. The runner uploads only the basename with overwrite enabled, so a unique local directory alone does not prevent collisions.

```bash
skill_dir=/opt/managed-skills/qwen-image
mkdir -p /opt/data/cache/images
job=$(mktemp -d /opt/data/cache/images/qwen-XXXXXXXX)
upload_1="$job/${job##*/}-reference-1-${reference_1##*/}"
upload_2="$job/${job##*/}-reference-2-${reference_2##*/}"
cp -- "$reference_1" "$upload_1"
cp -- "$reference_2" "$upload_2"
python3 /opt/hermes/optional-skills/creative/comfyui/scripts/run_workflow.py \
  --workflow "$skill_dir/editing-2.api.json" \
  --schema "$skill_dir/editing-2.schema.json" \
  --args '{"prompt":"Use <image1> as the canvas. Apply the shirt from <image2>, preserving everything else."}' \
  --input-image "reference_1=$upload_1" \
  --input-image "reference_2=$upload_2" \
  --host "$COMFYUI_URL" \
  --output-dir "$job"
```

For one or three references, change both filenames to the matching variant, copy each real reference to its own job-specific basename as above, and supply exactly one or three named `--input-image` flags. The runner uploads each file and injects its server-side filename through the schema. Omit `reference_N` keys from the JSON argument; explicit keys would override the uploaded names. Local reference paths belong in `--input-image`, not JSON parameters.

Wait for the stock runner to finish. Read its result and any warnings. A successful delivery requires downloaded files in `outputs[].file`, not just a submitted prompt ID or `status=success` with no files. On failure, report the actual error instead of inventing a result.

## Return the images

Return each downloaded absolute file path on its own line as `MEDIA:/absolute/path/to/file.png`, outside code fences. Use the actual `outputs[].file` paths, which may include subdirectories. Add a brief description of the result. Hermes' Matrix instructions document this syntax and send images as inline photos. Keep the downloaded paths available for follow-up edits.
