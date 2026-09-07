from __future__ import annotations

import asyncio
import audioop
import base64
import binascii
import json
import os
import uuid
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable, Mapping, Protocol
from urllib.parse import urlsplit, urlunsplit

import httpx
from example_fastapi_server.protocol import encode_audio_packet
from fastapi import FastAPI, Request, WebSocket
from fastapi.responses import JSONResponse, PlainTextResponse, Response
from starlette.datastructures import UploadFile
from starlette.websockets import WebSocketDisconnect

PCM16_SAMPLE_WIDTH = 2
NATIVE_SAMPLE_RATE = 16_000
DEFAULT_INPUT_SAMPLE_RATE = 24_000


class NativeSocket(Protocol):
    async def send(self, message: str | bytes) -> None: ...

    async def recv(self) -> str | bytes: ...

    async def close(self) -> None: ...


NativeSocketFactory = Callable[[str], Awaitable[NativeSocket]]


@dataclass(frozen=True)
class AdapterSettings:
    model_name: str
    default_language: str
    native_http_url: str
    native_ws_url: str

    @classmethod
    def from_environment(cls) -> AdapterSettings:
        native_http_url = os.environ.get(
            "NATIVE_SERVER_URL", "http://127.0.0.1:8010"
        ).rstrip("/")
        native_ws_url = os.environ.get("NATIVE_WS_URL") or native_websocket_url(
            native_http_url
        )
        return cls(
            model_name=os.environ.get(
                "MODEL_NAME", "nvidia/nemotron-3.5-asr-streaming-0.6b"
            ),
            default_language=os.environ.get("DEFAULT_LANGUAGE", "en"),
            native_http_url=native_http_url,
            native_ws_url=native_ws_url,
        )


@dataclass(frozen=True)
class TranscriptionConfig:
    sample_rate: int
    language: str
    turn_detection: Any


@dataclass
class Pcm16Resampler:
    source_rate: int
    state: Any = None

    def convert(self, audio: bytes) -> bytes:
        if len(audio) % PCM16_SAMPLE_WIDTH:
            raise AdapterError(
                "invalid_audio", "PCM16 audio must contain whole samples"
            )
        if self.source_rate == NATIVE_SAMPLE_RATE:
            return audio
        converted, self.state = audioop.ratecv(
            audio,
            PCM16_SAMPLE_WIDTH,
            1,
            self.source_rate,
            NATIVE_SAMPLE_RATE,
            self.state,
        )
        return converted


@dataclass
class CumulativePartialStabilizer:
    emitted: str = ""

    def delta(self, hypothesis: str) -> str:
        if not hypothesis.startswith(self.emitted):
            return ""
        delta = hypothesis[len(self.emitted) :]
        self.emitted = hypothesis
        return delta

    def reset(self) -> None:
        self.emitted = ""


@dataclass
class OpenAISession:
    settings: AdapterSettings
    config: TranscriptionConfig = field(init=False)
    session_id: str = field(default_factory=lambda: identifier("sess"))
    item_id: str = field(default_factory=lambda: identifier("item"))
    packet_sequence: int = 0
    upstream: NativeSocket | None = None
    active_turn: bool = False
    finalizing: bool = False
    resampler: Pcm16Resampler = field(init=False)
    partials: CumulativePartialStabilizer = field(
        default_factory=CumulativePartialStabilizer
    )

    def __post_init__(self) -> None:
        self.config = TranscriptionConfig(
            sample_rate=DEFAULT_INPUT_SAMPLE_RATE,
            language=self.settings.default_language,
            turn_detection=None,
        )
        self.resampler = Pcm16Resampler(DEFAULT_INPUT_SAMPLE_RATE)

    async def open(self, socket_factory: NativeSocketFactory) -> None:
        self.upstream = await socket_factory(self.settings.native_ws_url)

    async def close(self) -> None:
        if self.upstream is not None:
            await self.upstream.close()
            self.upstream = None

    def session_payload(self) -> dict[str, Any]:
        return {
            "id": self.session_id,
            "object": "realtime.transcription_session",
            "type": "transcription",
            "model": self.settings.model_name,
            "audio": {
                "input": {
                    "format": {"type": "audio/pcm", "rate": self.config.sample_rate},
                    "transcription": {
                        "model": self.settings.model_name,
                        "language": self.config.language,
                    },
                    "turn_detection": self.config.turn_detection,
                }
            },
        }

    def update(self, payload: object) -> None:
        if self.active_turn:
            raise AdapterError(
                "invalid_state", "Cannot update the audio format during an active turn"
            )
        self.config = parse_session_update(payload, self.settings)
        self.resampler = Pcm16Resampler(self.config.sample_rate)
        self.partials.reset()

    async def append(self, encoded_audio: object) -> None:
        if not isinstance(encoded_audio, str):
            raise AdapterError(
                "invalid_request_error",
                "input_audio_buffer.append requires an audio string",
                "audio",
            )
        try:
            audio = base64.b64decode(encoded_audio, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise AdapterError(
                "invalid_audio", "audio must be base64 PCM16", "audio"
            ) from exc
        if not audio:
            return
        if len(audio) % PCM16_SAMPLE_WIDTH:
            raise AdapterError(
                "invalid_audio", "PCM16 audio must contain whole samples", "audio"
            )
        if self.finalizing:
            raise AdapterError(
                "invalid_state", "Cannot append audio after input_audio_buffer.commit"
            )
        if not self.active_turn:
            await self.start_turn()
        pcm16 = self.resampler.convert(audio)
        if not pcm16:
            return
        packet = encode_audio_packet(
            {
                "audioSequence": self.packet_sequence,
                "sampleRate": NATIVE_SAMPLE_RATE,
                "channels": 1,
                "format": "pcm_s16le",
                "frames": len(pcm16) // PCM16_SAMPLE_WIDTH,
            },
            pcm16,
        )
        await self.socket().send(packet)
        self.packet_sequence += 1

    async def commit(self) -> None:
        if not self.active_turn:
            raise AdapterError(
                "invalid_state", "input_audio_buffer.commit requires appended audio"
            )
        if self.finalizing:
            raise AdapterError(
                "invalid_state", "input_audio_buffer.commit was already sent"
            )
        await self.socket().send(
            json.dumps({"type": "finalize"}, separators=(",", ":"))
        )
        self.finalizing = True

    async def clear(self) -> None:
        if self.active_turn:
            await self.socket().send(
                json.dumps({"type": "reset"}, separators=(",", ":"))
            )
        self.reset_turn()

    async def start_turn(self) -> None:
        self.item_id = identifier("item")
        self.packet_sequence = 0
        self.finalizing = False
        self.resampler = Pcm16Resampler(self.config.sample_rate)
        self.partials.reset()
        await self.socket().send(
            json.dumps(
                {
                    "type": "start",
                    "turnId": self.item_id,
                    "language": self.config.language,
                },
                separators=(",", ":"),
            )
        )
        self.active_turn = True

    async def receive_native(self) -> Mapping[str, Any]:
        message = await self.socket().recv()
        if isinstance(message, bytes):
            raise AdapterError(
                "upstream_error", "Native transcription server sent binary control data"
            )
        try:
            payload = json.loads(message)
        except json.JSONDecodeError as exc:
            raise AdapterError(
                "upstream_error", "Native transcription server sent invalid JSON"
            ) from exc
        if not isinstance(payload, Mapping):
            raise AdapterError(
                "upstream_error", "Native transcription server sent an invalid event"
            )
        return payload

    def native_events(self, payload: Mapping[str, Any]) -> list[dict[str, Any]]:
        event_type = payload.get("type")
        turn_id = payload.get("turnId")
        if isinstance(turn_id, str) and turn_id != self.item_id:
            return []
        if event_type == "partial":
            if not self.active_turn:
                return []
            hypothesis = text_field(payload, "partialText", "text")
            delta = self.partials.delta(hypothesis)
            if delta:
                return [
                    transcription_event(
                        "conversation.item.input_audio_transcription.delta",
                        self.item_id,
                        delta=delta,
                    )
                ]
            return []
        if event_type == "final":
            if not self.active_turn:
                return []
            transcript = text_field(payload, "text")
            self.active_turn = False
            self.finalizing = False
            return [
                transcription_event(
                    "conversation.item.input_audio_transcription.completed",
                    self.item_id,
                    transcript=transcript,
                )
            ]
        if event_type == "error":
            if not self.active_turn:
                return []
            error = payload.get("error")
            if isinstance(error, Mapping):
                message = str(error.get("message", "Native transcription failed"))
                code = str(error.get("code", "upstream_error"))
            else:
                message = str(payload.get("message", "Native transcription failed"))
                code = str(payload.get("code", "upstream_error"))
            self.active_turn = False
            self.finalizing = False
            return [error_event(AdapterError(code, message), self.item_id)]
        if event_type == "completion" and payload.get("status") not in (
            None,
            "completed",
            "no_speech",
        ):
            if not self.active_turn:
                return []
            error = payload.get("error")
            message = (
                str(error.get("message", "Native transcription failed"))
                if isinstance(error, Mapping)
                else "Native transcription failed"
            )
            self.active_turn = False
            self.finalizing = False
            return [error_event(AdapterError("upstream_error", message), self.item_id)]
        return []

    def reset_turn(self) -> None:
        self.item_id = identifier("item")
        self.active_turn = False
        self.finalizing = False
        self.packet_sequence = 0
        self.resampler = Pcm16Resampler(self.config.sample_rate)
        self.partials.reset()

    def socket(self) -> NativeSocket:
        if self.upstream is None:
            raise AdapterError(
                "upstream_unavailable", "Native transcription server is unavailable"
            )
        return self.upstream


@dataclass(frozen=True)
class AdapterError(Exception):
    code: str
    message: str
    param: str | None = None
    status_code: int = 400


def identifier(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex}"


def native_websocket_url(http_url: str) -> str:
    parsed = urlsplit(http_url)
    if parsed.scheme not in ("http", "https") or not parsed.netloc:
        raise ValueError("NATIVE_SERVER_URL must be an absolute HTTP URL")
    scheme = "wss" if parsed.scheme == "https" else "ws"
    return urlunsplit((scheme, parsed.netloc, "/api/v1/ws/transcribe", "", ""))


def requested_language(value: object, default: str) -> str:
    if isinstance(value, str) and value != "":
        return value
    return default


def parse_session_update(
    payload: object, settings: AdapterSettings
) -> TranscriptionConfig:
    session = object_field(payload, "session")
    if session.get("type") != "transcription":
        raise AdapterError(
            "invalid_request_error",
            "session.type must be transcription",
            "session.type",
        )
    audio = object_field(session, "audio", "session.audio")
    input_audio = object_field(audio, "input", "session.audio.input")
    audio_format = object_field(input_audio, "format", "session.audio.input.format")
    if audio_format.get("type") != "audio/pcm":
        raise AdapterError(
            "invalid_request_error",
            "audio.input.format.type must be audio/pcm",
            "session.audio.input.format.type",
        )
    sample_rate = audio_format.get("rate", DEFAULT_INPUT_SAMPLE_RATE)
    if (
        isinstance(sample_rate, bool)
        or not isinstance(sample_rate, int)
        or sample_rate <= 0
    ):
        raise AdapterError(
            "invalid_request_error",
            "audio.input.format.rate must be a positive integer",
            "session.audio.input.format.rate",
        )
    transcription = input_audio.get("transcription")
    if transcription is None:
        transcription = {}
    if not isinstance(transcription, Mapping):
        raise AdapterError(
            "invalid_request_error",
            "audio.input.transcription must be an object",
            "session.audio.input.transcription",
        )
    return TranscriptionConfig(
        sample_rate=sample_rate,
        language=requested_language(
            transcription.get("language"), settings.default_language
        ),
        turn_detection=input_audio.get("turn_detection"),
    )


def object_field(value: object, key: str, name: str | None = None) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise AdapterError("invalid_request_error", "Request event must be an object")
    nested = value.get(key)
    if not isinstance(nested, Mapping):
        raise AdapterError(
            "invalid_request_error", f"{name or key} must be an object", name or key
        )
    return nested


def text_field(payload: Mapping[str, Any], *keys: str) -> str:
    for key in keys:
        value = payload.get(key)
        if isinstance(value, str):
            return value
    return ""


def openai_error(error: AdapterError) -> dict[str, Any]:
    return {
        "error": {
            "message": error.message,
            "type": "invalid_request_error"
            if error.status_code < 500
            else "server_error",
            "param": error.param,
            "code": error.code,
        }
    }


def event(event_type: str, **payload: Any) -> dict[str, Any]:
    return {"event_id": identifier("event"), "type": event_type, **payload}


def transcription_event(
    event_type: str, item_id: str, **payload: Any
) -> dict[str, Any]:
    return event(event_type, item_id=item_id, content_index=0, **payload)


def error_event(error: AdapterError, item_id: str | None = None) -> dict[str, Any]:
    payload: dict[str, Any] = {"error": openai_error(error)["error"]}
    if item_id is not None:
        payload.update(item_id=item_id, content_index=0)
    return event("error", **payload)


async def connect_native(url: str) -> NativeSocket:
    from websockets.asyncio.client import connect

    return await connect(url)


async def decode_upload(upload: UploadFile) -> bytes:
    source = await upload.read()
    if not source:
        raise AdapterError("invalid_audio", "file must not be empty", "file")
    process = await asyncio.create_subprocess_exec(
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        "pipe:0",
        "-f",
        "s16le",
        "-acodec",
        "pcm_s16le",
        "-ac",
        "1",
        "-ar",
        str(NATIVE_SAMPLE_RATE),
        "pipe:1",
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    pcm16, stderr = await process.communicate(source)
    if process.returncode != 0:
        message = (
            stderr.decode("utf-8", "replace").strip()
            or "ffmpeg could not decode the uploaded audio"
        )
        raise AdapterError("invalid_audio", message, "file")
    if not pcm16:
        raise AdapterError(
            "invalid_audio", "file did not contain decodable audio", "file"
        )
    return pcm16


async def native_transcription(
    client: httpx.AsyncClient, pcm16: bytes, language: str
) -> str:
    try:
        response = await client.post(
            "/transcribe-pcm16",
            params={
                "sample_rate": NATIVE_SAMPLE_RATE,
                "encoding": "pcm16",
                "language": language,
            },
            content=pcm16,
            headers={"content-type": "application/octet-stream"},
        )
    except httpx.HTTPError as exc:
        raise AdapterError(
            "upstream_unavailable",
            "Native transcription server is unavailable",
            status_code=502,
        ) from exc
    if response.is_error:
        raise AdapterError(
            "upstream_error",
            "Native transcription server rejected the audio",
            status_code=502,
        )
    try:
        payload = response.json()
    except json.JSONDecodeError as exc:
        raise AdapterError(
            "upstream_error",
            "Native transcription server returned invalid JSON",
            status_code=502,
        ) from exc
    if not isinstance(payload, Mapping):
        raise AdapterError(
            "upstream_error",
            "Native transcription server returned an invalid response",
            status_code=502,
        )
    return text_field(payload, "text")


def create_app(
    settings: AdapterSettings | None = None,
    socket_factory: NativeSocketFactory = connect_native,
) -> FastAPI:
    adapter_settings = settings or AdapterSettings.from_environment()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.native_http = httpx.AsyncClient(
            base_url=adapter_settings.native_http_url, timeout=60.0
        )
        try:
            yield
        finally:
            await app.state.native_http.aclose()

    app = FastAPI(lifespan=lifespan)

    @app.exception_handler(AdapterError)
    async def adapter_error(_: Request, exc: AdapterError) -> JSONResponse:
        return JSONResponse(openai_error(exc), status_code=exc.status_code)

    @app.get("/health")
    async def health(request: Request) -> JSONResponse:
        try:
            response = await request.app.state.native_http.get("/health")
        except httpx.HTTPError as exc:
            raise AdapterError(
                "upstream_unavailable",
                "Native transcription server is unavailable",
                status_code=503,
            ) from exc
        if response.is_error:
            raise AdapterError(
                "upstream_unavailable",
                "Native transcription server is unavailable",
                status_code=503,
            )
        return JSONResponse({"status": "ok"})

    @app.get("/v1/models")
    async def models() -> dict[str, Any]:
        return {
            "object": "list",
            "data": [
                {
                    "id": adapter_settings.model_name,
                    "object": "model",
                    "created": 0,
                    "owned_by": "realtimestt",
                }
            ],
        }

    @app.post("/v1/audio/transcriptions")
    async def transcriptions(request: Request) -> Response:
        try:
            form = await request.form()
        except Exception as exc:
            raise AdapterError(
                "invalid_request_error", "Request must be multipart form data"
            ) from exc
        file = form.get("file")
        if not isinstance(file, UploadFile):
            raise AdapterError("invalid_request_error", "file is required", "file")
        response_format = form.get("response_format", "json")
        if response_format not in ("json", "text"):
            raise AdapterError(
                "invalid_request_error",
                "response_format must be json or text",
                "response_format",
            )
        language = form.get("language")
        if language is not None and not isinstance(language, str):
            raise AdapterError(
                "invalid_request_error", "language must be a string", "language"
            )
        pcm16 = await decode_upload(file)
        transcript = await native_transcription(
            request.app.state.native_http,
            pcm16,
            requested_language(language, adapter_settings.default_language),
        )
        if response_format == "text":
            return PlainTextResponse(transcript)
        return JSONResponse({"text": transcript})

    @app.websocket("/v1/realtime")
    async def realtime(websocket: WebSocket) -> None:
        if websocket.query_params.get("intent") != "transcription":
            await websocket.accept()
            await websocket.send_json(
                error_event(
                    AdapterError(
                        "invalid_request_error", "intent=transcription is required"
                    )
                )
            )
            await websocket.close(code=1008)
            return
        await websocket.accept()
        session = OpenAISession(adapter_settings)
        try:
            await session.open(socket_factory)
        except Exception:
            await websocket.send_json(
                error_event(
                    AdapterError(
                        "upstream_unavailable",
                        "Native transcription server is unavailable",
                        status_code=502,
                    )
                )
            )
            await websocket.close(code=1011)
            return
        await websocket.send_json(
            event("session.created", session=session.session_payload())
        )
        client_message = asyncio.create_task(websocket.receive_json())
        native_message = asyncio.create_task(session.receive_native())
        try:
            while True:
                done, _ = await asyncio.wait(
                    (client_message, native_message),
                    return_when=asyncio.FIRST_COMPLETED,
                )
                if client_message in done:
                    try:
                        payload = client_message.result()
                        if not isinstance(payload, Mapping):
                            raise AdapterError(
                                "invalid_request_error",
                                "Request event must be an object",
                            )
                        responses = await websocket_event(session, payload)
                    except AdapterError as exc:
                        responses = [error_event(exc, session.item_id)]
                    for response in responses:
                        await websocket.send_json(response)
                    client_message = asyncio.create_task(websocket.receive_json())
                if native_message in done:
                    try:
                        responses = session.native_events(native_message.result())
                    except AdapterError as exc:
                        responses = [error_event(exc, session.item_id)]
                    for response in responses:
                        await websocket.send_json(response)
                    native_message = asyncio.create_task(session.receive_native())
        except WebSocketDisconnect:
            pass
        finally:
            client_message.cancel()
            native_message.cancel()
            await session.close()

    return app


async def websocket_event(
    session: OpenAISession, payload: Mapping[str, Any]
) -> list[dict[str, Any]]:
    event_type = payload.get("type")
    if event_type == "session.update":
        session.update(payload)
        return [event("session.updated", session=session.session_payload())]
    if event_type == "input_audio_buffer.append":
        await session.append(payload.get("audio"))
        return []
    if event_type == "input_audio_buffer.commit":
        await session.commit()
        return []
    if event_type == "input_audio_buffer.clear":
        await session.clear()
        return []
    raise AdapterError(
        "invalid_request_error", f"Unsupported event type: {event_type}", "type"
    )


app = create_app()
