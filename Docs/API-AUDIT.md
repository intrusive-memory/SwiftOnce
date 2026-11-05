# ElevenLabs API audit — SwiftOnce v1.0.0

Date: 2026-11-04. Scope: OPERATION RATIONED MEGAPHONE, Sortie 1.

Sources: live API reference pages (text-to-speech convert, text-to-voice design/create, voices delete),
plus two read-only live calls: `GET /v1/models` and `GET /v1/user/subscription` (account tier `creator`).
SwiftOnce side is read from tag `v1.0.0`. Items marked **unverified** could not be confirmed from the
reference pages or live calls and need a check before a sortie relies on them.

## 1. Models (`GET /v1/models`, live)

| Model id | TTS | Max chars / request (free = subscribed) | Cost multiplier | Languages | Concurrency group | In SwiftOnce `Model` enum |
|---|---|---|---|---|---|---|
| `eleven_v4` | yes | **10000** | 1.0 | 94 | `standard_eleven_v4` | **missing** |
| `eleven_v4_turbo` | yes | **10000** | 0.5 | 94 | `standard_eleven_v4` | **missing** |
| `eleven_v3` | yes | 5000 | 1.0 | 74 | `standard` | `.v3` |
| `eleven_v3_conversational` | yes | 5000 | 0.5 | 74 | `standard_eleven_v3` | missing |
| `eleven_multilingual_v2` | yes | 10000 | 1.0 | 29 | `standard` | `.multilingualV2` |
| `eleven_flash_v2_5` | yes | 40000 | 0.5 | 32 | `turbo` | `.flashV2_5` |
| `eleven_turbo_v2_5` | yes | 40000 | 0.5 | 32 | `turbo` | `.turboV2_5` |
| `eleven_turbo_v2` | yes | 30000 | 0.5 | 1 | `turbo` | `.turboV2` |
| `eleven_flash_v2` | yes | 30000 | 0.5 | 1 | `turbo` | `.flashV2` |
| `eleven_english_sts_v2` | no (voice conversion) | 5000 | 1.0 | 1 | own | n/a |
| `eleven_multilingual_sts_v2` | no (voice conversion) | 10000 | 1.0 | 29 | own | n/a |

Notes:
- `token_cost_factor` is 1.0 for every model; the cost lever is `model_rates.character_cost_multiplier`.
- `eleven_v4` / `eleven_v4_turbo` have `can_be_finetuned: true`, `can_use_style: false`, `can_use_speaker_boost: false`.
  So `style` and `use_speaker_boost` have no effect on v4 (the API accepts them; effect is expected to be none).
- v4 and v4 Turbo share one concurrency group, `standard_eleven_v4`, separate from `standard`.
- Per-request limit for the v4 models is 10000 characters; v3 is 5000. v1.0.0 does no length checking.
- `eleven_multilingual_v1` / `eleven_monolingual_v1` (in the v1.0.0 enum) are no longer returned by `/v1/models`.

| Area | API today | SwiftOnce v1.0.0 | Gap |
|---|---|---|---|
| Model list | 11 models above | Closed enum of 8; `Model` has no v4, no passthrough string | G1 |
| Default model | Plan default is `eleven_v4` (API default is `eleven_multilingual_v2`) | `defaultModel = .multilingualV2` | G2 |
| Model discovery | `GET /v1/models` | No endpoint, no API | G3 |
| Retired models | v1 models absent from live list | Still in enum, `isLegacy` true | G1 (minor) |

## 2. Text-to-speech (`POST /v1/text-to-speech/{voice_id}`)

| Field | API today | SwiftOnce v1.0.0 | Gap |
|---|---|---|---|
| `text` | required; per-model max (v4: 10000) | sent as is | G4 (no length check or chunking) |
| `model_id` | any TTS-capable id; API default `eleven_multilingual_v2` | enum raw value only | G1 |
| `language_code` | ISO 639-1; ignored by `multilingual_v2` | sent | none |
| `voice_settings` | see section 6 | sent (`stability`, `similarity_boost`, `style`, `speed`, `use_speaker_boost`) | G9 (no `clone_strength`) |
| `pronunciation_dictionary_locators` | max 3 | sent, not limited | none |
| `seed` | 0 to 4294967295 | sent as Int | none |
| `previous_text` / `next_text` | continuity; ignored if matching request ids sent; no documented length cap | sent | none |
| `previous_request_ids` / `next_request_ids` | max 3 each; best on same model | sent | G5 (no way to read the `request-id` response header, so ids cannot be produced) |
| `apply_text_normalization` | `auto` / `on` / `off`, default `auto` | `TextNormalization` enum, sent | none |
| `apply_language_text_normalization` | bool, Japanese only | absent | G9 (low priority) |
| `use_pvc_as_ivc` | bool | absent | G9 (low priority) |
| `audio_effects` | object (filter, distance, environment, noise, send_level, pan) | absent | G9 (low priority) |
| `output_format` (query) | 29 values (mp3, opus, pcm, wav, alaw, ulaw); MP3 192k needs Creator+, PCM/WAV 44.1k needs Pro+ | all 29 present, incl. `pcm_24000` | none |
| `enable_logging` (query) | default true; false = zero retention, Enterprise only | absent | G9 (low priority) |
| `optimize_streaming_latency` (query) | deprecated, 0 to 4 | `StreamingLatencyOptimization` enum | none (deprecated) |
| Audio tags (v4) | Not documented on the TTS reference page | not applicable (text passthrough) | **unverified**, X-02 needs one live call |
| Stream and timestamp variants | `/stream`, `/with-timestamps`, `/stream/with-timestamps` | all four endpoints | none |

## 3. Text-to-voice design (`POST /v1/text-to-voice/design`)

Current design `model_id`: **`eleven_multilingual_ttv_v2`** (documented default). The only other option is
`eleven_ttv_v3`. No v4 design model is documented.

| Field | API today | SwiftOnce v1.0.0 | Gap |
|---|---|---|---|
| `voice_description` | required, no documented length limit | sent | none |
| `model_id` | `eleven_multilingual_ttv_v2` (default), `eleven_ttv_v3` | `VoiceDesignModel` `.v2`, `.v3`; omitted when nil (API default applies) | none |
| `text` | optional, 100 to 1000 characters | sent, no length check | G6 |
| `auto_generate_text` | bool, default false | absent | G6 |
| `loudness` | -1 to 1, default 0.5 | sent | none |
| `guidance_scale` | default 5 | sent | none |
| `seed` | int | sent | none |
| `quality` | number | absent | G6 (low priority) |
| `reference_audio_base64`, `prompt_strength` | `eleven_ttv_v3` only | absent | G6 (low priority) |
| `stream_previews`, `should_enhance`, remix ids | optional | absent | G6 (low priority) |
| `output_format` (query) | same list as TTS minus wav | not sent | G6 (low priority) |
| Response | `previews[]` (`audio_base_64`, `generated_voice_id`, `media_type`, `duration_secs`, `language`), `text` | decoded exactly | none |
| 409 | "generation for this preview already in progress, retry" | falls to `httpError(409)` | G7 |

## 4. Text-to-voice create (`POST /v1/text-to-voice`)

| Field | API today | SwiftOnce v1.0.0 | Gap |
|---|---|---|---|
| `generated_voice_id`, `voice_name`, `voice_description` | required | sent | none |
| `labels` | map string to string | sent | none |
| `played_not_selected_voice_ids` | optional | absent | G6 (low priority) |
| Response | `Voice` object (`voice_id`, `category` = `generated`, etc.) | decoded as `Voice` | none |
| Voice-limit error | Not documented on the reference page; **unverified** (see section 8) | falls to `httpError` | G8 |

## 5. Delete voice (`DELETE /v1/voices/{voice_id}`)

| Area | API today | SwiftOnce v1.0.0 | Gap |
|---|---|---|---|
| Endpoint | `DELETE /v1/voices/{voice_id}`, 200 `{"status":"ok"}`; 500 on failure; 422 validation | **absent** (`Endpoint` has `GET /v1/voices/{id}` only; method switch has no DELETE) | G10 |
| Cache | n/a | voice cache would need invalidating after delete | G10 |

Deleting is required so a design flow does not leave a slot used (mission rule 4).

## 6. Voice settings

| Setting | API today (default; documented range) | SwiftOnce v1.0.0 | Gap |
|---|---|---|---|
| `stability` | 0.5; no range on the reference page (0 to 1 in practice) | Double, default 0.5, unvalidated | none |
| `similarity_boost` | 0.75; same | Double, default 0.75 | none |
| `style` | 0; same. Not supported by v4 (`can_use_style: false`) | optional | none |
| `speed` | 1.0; no range on the page | optional | none |
| `use_speaker_boost` | true. Not supported by v4 | optional | none |
| `clone_strength` | 0 to 1; only for professional clones fine-tuned on v4 | absent | G9 (low priority) |

## 7. Subscription and limits (`GET /v1/user/subscription`, live, account `creator`)

| Field | Value on this account |
|---|---|
| `tier` | `creator` |
| `character_limit` / `character_count` | 130996 / 0 (credits remaining 130996) |
| `max_character_limit_extension` | 203000 (`can_extend_character_limit: false`) |
| `next_character_count_reset_unix` | 1796280074 |
| `voice_limit` | **30** |
| `voice_slots_used` | **4** (26 free) |
| `professional_voice_limit` / used | 1 / 0 |
| `voice_add_edit_counter` / `max_voice_add_edits` | 0 / 95 |
| `can_use_instant_voice_cloning` | true |
| `status` | `active` |
| Concurrency | **Not in the response.** No concurrency field exists; the limit is a plan property. |

Concurrency per plan comes from ElevenLabs' help-center article "API - Error Code 429" (secondary source,
dated; **unverified against current docs**; the official concurrency page returned HTTP 403): Free 2, Starter 3,
Creator 5, Pro 10, Scale 15, Business 15. Third-party 2026 articles give higher, conflicting numbers for
Flash/Turbo. Requests above the limit are queued by the service up to a point; the 429 codes are
`too_many_concurrent_requests` (queue or wait) and `system_busy` (back off with jitter). Plan comment in
`Configuration.swift` matches the help-center numbers. The default `maxConcurrentRequests = 8` exceeds Free,
Starter, and Creator limits, so those users get 429s by default. EL-2.5's default of 2 matches Free only; this
account (Creator) would be 5.

| Area | API today | SwiftOnce v1.0.0 | Gap |
|---|---|---|---|
| Subscription | `GET /v1/user/subscription` | absent | G3 |
| Concurrency gate | per plan, per model group | one global gate, default 8 | G11 |

## 8. Errors and retry

| Condition | API today | SwiftOnce v1.0.0 | Gap |
|---|---|---|---|
| 401 | invalid key; ElevenLabs also reports **quota exhaustion** with a 401 and a `detail.status` of `quota_exceeded` (secondary knowledge; **unverified** on these pages) | all 401 become `.invalidAPIKey`; `.quotaExceeded` is declared but never thrown | G8 |
| 422 | validation error, `detail[]` with `loc`, `msg`, `type` | `.invalidRequest(body)` | none |
| 429 | `too_many_concurrent_requests`, `system_busy`; `Retry-After` header | retries up to `maxRetries` (3), honours `Retry-After` as Int seconds, else exponential backoff capped at 30 s; throws `.rateLimited` | G12 (no differentiation of the two 429 codes; HTTP-date `Retry-After` ignored) |
| 5xx | `DELETE` documents 500 | no retry; `.httpError` | G13 (O-05 / OQ-7: retry 5xx or not is a decision) |
| 409 (design, create) | preview generation in progress, retry | `.httpError(409)` | G7 |
| Voice limit reached | **unverified** (not on the reference pages; plan limit is `voice_limit`) | `.httpError` with body | G8 |
| 404 | unknown voice | `.voiceNotFound(body)` | none |

## 9. Numbered gap list

1. `Model` is a closed enum of 8 with no `eleven_v4`, `eleven_v4_turbo`, `eleven_v3_conversational`, and no passthrough for unknown ids. Need `.v4`, `.v4Turbo` plus a way to pass any model id string. Retired v1 models can stay but should be flagged.
2. Default model: `SwiftOnceConfiguration.defaultModel` is `.multilingualV2`; mission rule 5 wants `eleven_v4`.
3. No `GET /v1/models` and no `GET /v1/user/subscription` endpoint or types. Needed for pre-flight: per-model `maximum_text_length_per_request`, `character_cost_multiplier`, `can_do_text_to_speech`, plus `voice_limit`, `voice_slots_used`, `character_limit`, `character_count`, `tier`.
4. No client-side text length check against the model's per-request limit (v4: 10000, v3: 5000). A too-long request is rejected by the API with a 422; surface a clear error before the call or document that callers chunk.
5. No access to the `request-id` response header on speech calls, so `previous_request_ids` / `next_request_ids` (max 3 each) cannot be filled. Note the API ignores `previous_text` when request ids are sent.
6. Voice design is missing optional fields: `auto_generate_text`, `quality`, `reference_audio_base64`, `prompt_strength` (v3 only), `stream_previews`, `should_enhance`, `output_format`, and `played_not_selected_voice_ids` on create. `text` must be 100 to 1000 characters when given; no check. Only `auto_generate_text` and the text check matter for the mission.
7. HTTP 409 on design/create ("generation in progress, retry") is not mapped or retried.
8. `.quotaExceeded` is never thrown, and a voice-limit failure has no typed error. Both need a decision after one observation of the real error body (quota case is believed to be 401; voice-limit shape unverified). Tests should use `MockHTTPClient`, not live spend.
9. Minor request-field gaps: `VoiceSettings.clone_strength`, `apply_language_text_normalization`, `use_pvc_as_ivc`, `audio_effects`, `enable_logging`. Not needed by the mission; low priority.
10. No `DELETE /v1/voices/{voice_id}` (200 `{"status":"ok"}`, 500 on failure). Needed so a design to save to delete test frees its slot. Must also invalidate the voice cache.
11. `maxConcurrentRequests` default is 8, above the Free/Starter/Creator plan limits (2/3/5). Either lower the default or derive it from tier; the gate is global, not per concurrency group (v4 has its own group `standard_eleven_v4`).
12. 429 handling does not distinguish `too_many_concurrent_requests` from `system_busy`, and `Retry-After` is parsed as an integer only (HTTP-date form is ignored).
13. 5xx responses are not retried (O-05 is stale: only 429 retries). Decide whether to retry 5xx with backoff (OQ-7).
14. Audio tags on v4 (X-02) remain unverified by documentation; the TTS reference page says nothing about them. Settle with the single live call in a later sortie. The doc also states `style` and `use_speaker_boost` are unsupported on v4.

Cross-reference: X-01 confirmed (v4 and v4 Turbo exist, 10000 chars). X-03 confirmed: design `model_id`
`eleven_multilingual_ttv_v2` (default) or `eleven_ttv_v3`, response shape unchanged. X-04: no concurrency
field in `/v1/user/subscription`; see section 7.
