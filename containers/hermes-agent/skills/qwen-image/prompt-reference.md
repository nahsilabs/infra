# Qwen prompt reference

Adapted and shortened from iamyoki's `qwen-image-2.1-skill`, commit [`32b8100e70299b56478a35a9f1d5703605cdba46`](https://github.com/iamyoki/qwen-image-2.1-skill/tree/32b8100e70299b56478a35a9f1d5703605cdba46), specifically `skills/qwen-image-2-1-prompter/references/t2i_rules.md` and `edit_rules.md`. Copyright 2026 iamyoki. Apache-2.0; the complete upstream license is in `prompt-reference.LICENSE`.

This is an unofficial reference. Upstream attributes its rules to Alibaba's Qwen-Image-2.1 prompt-rewriting specifications. Local modifications remove fixed word/sentence counts and API-specific output fields, use ordered image tags for all editing variants, and defer canvas size to the mounted workflow controls. All required guidance is vendored here; running the skill requires no remote reference fetch.

## Generation

Write an English description of the finished image. Preserve the user's subjects, counts, colors, positions, and exact rendered text. Start with the medium, subject, and setting. Describe the composition in spatial order, followed by relevant materials and lighting. Make shadows, reflections, and scale consistent unless the user asks for an impossible scene.

Use enough detail for the requested scene. A single object needs less prose than a poster with several regions. Add plausible missing details only where they support the brief. Replace empty quality claims with concrete visual properties. Keep ratios and pixel dimensions in workflow parameters, not the prompt.

For readable text, copy every requested character in straight double quotes, retaining its original script, punctuation, and spacing. Name its position and typography. Describe separate lines explicitly. Add no incidental slogans or labels to scenes that do not call for text.

Example: `An editorial product photograph shows a glossy red ceramic teapot centered on a pale wooden table beside a window. Soft morning light enters from the left, with a gentle shadow extending to the right. The background is uncluttered and softly out of focus.`

## Editing and reference-guided generation

Inspect the images before writing. Lead with the requested operation. Bind each supplied image tag to one role. `<image1>` is the canvas or primary subject; `<image2>` and `<image3>`, when supplied, contribute only their named attributes. Point to an identity reference rather than trying to reconstruct facial features in prose.

For a local edit, describe the changed attribute precisely and preserve everything else with one short clause. Preserve identity, accessories, layout, and medium unless the user targets them. Avoid re-describing the appearance of unchanged content; that can make the model redraw it. For a new scene built from references, describe the new composition and lighting while assigning each reference's contribution explicitly. Expand only as far as the request needs.

Use Chinese prose for Chinese editing instructions and English prose otherwise. Rendered text is a separate decision. Preserve exact user-supplied text or the requested language. Otherwise retain the image's dominant text language, or use the user's language if there is no existing text. Preserve deliberate multilingual content. Add readable text only when its wording is established.

For outpainting, name the extension direction and describe what fills the added area while keeping the existing content fixed. Request the output canvas through workflow parameters.

Single-reference example: `Change the teapot in <image1> to cobalt blue. Preserve its shape, position, reflections, and all other content.`

Two-reference example: `Use <image1> as the canvas. Replace the person's shirt with the shirt from <image2>, matching its cut, fabric, and color to the person's pose. Preserve the person's identity, accessories, background, and composition.`

Three-reference example: `Use <image1> as the canvas. Replace the shirt with the shirt from <image2> and print the graphic from <image3> on its front, following the fabric folds. Preserve the person's identity, pose, accessories, and all other content.`

## Media instruction provenance

Hermes' upstream `agent/prompt_builder.py` at commit [`601b550b4b5addecc0b6dacf9a472a54dd8c6799`](https://github.com/NousResearch/hermes-agent/blob/601b550b4b5addecc0b6dacf9a472a54dd8c6799/agent/prompt_builder.py) defines `_MEDIA_NATIVE` as an instruction to write `MEDIA:/absolute/path/to/file` in the response. The `matrix` platform hint incorporates it and says images send as inline photos. The skill uses that native delivery contract, not local Markdown image links.
