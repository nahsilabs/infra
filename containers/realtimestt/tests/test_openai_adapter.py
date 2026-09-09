import asyncio
import base64
import json

from example_fastapi_server.protocol import decode_audio_packet
from fastapi.testclient import TestClient
import openai_adapter

from openai_adapter import (
    AdapterSettings,
    CumulativePartialStabilizer,
    OpenAISession,
    Pcm16Resampler,
    create_app,
    parse_session_update,
    websocket_event,
)


def settings() -> AdapterSettings:
    return AdapterSettings(
        model_name="nvidia/nemotron-3.5-asr-streaming-0.6b",
        default_language="en",
        native_http_url="http://native:8010",
        native_ws_url="ws://native:8010/api/v1/ws/transcribe",
    )


def session_update(
    language: str | None = "fr-CA", rate: int = 24_000
) -> dict[str, object]:
    transcription: dict[str, object] = {"model": "ignored"}
    if language is not None:
        transcription["language"] = language
    return {
        "type": "session.update",
        "session": {
            "type": "transcription",
            "audio": {
                "input": {
                    "format": {"type": "audio/pcm", "rate": rate},
                    "transcription": transcription,
                    "turn_detection": None,
                }
            },
        },
    }


def test_session_language_forwards_nonempty_value_and_defaults_when_omitted() -> None:
    assert parse_session_update(session_update("fr-CA"), settings()).language == "fr-CA"
    assert parse_session_update(session_update(None), settings()).language == "en"


def test_cumulative_partials_never_retract_or_repeat() -> None:
    partials = CumulativePartialStabilizer()

    assert partials.delta("hello") == "hello"
    assert partials.delta("helxo") == ""
    assert partials.delta("hello there") == " there"


def test_final_transcript_is_authoritative_after_a_revised_partial() -> None:
    session = OpenAISession(settings())
    session.active_turn = True

    first = session.native_events({"type": "partial", "partialText": "hello"})
    revised = session.native_events({"type": "partial", "partialText": "helxo"})
    completed = session.native_events({"type": "final", "text": "helxo"})

    assert first[0]["delta"] == "hello"
    assert revised == []
    assert (
        completed[0]["type"] == "conversation.item.input_audio_transcription.completed"
    )
    assert completed[0]["transcript"] == "helxo"


def test_resampler_keeps_state_between_audio_frames() -> None:
    source = b"".join(
        sample.to_bytes(2, "little", signed=True) for sample in range(240)
    )
    first, second = source[:160], source[160:]
    streaming = Pcm16Resampler(24_000)
    whole = Pcm16Resampler(24_000)

    assert streaming.convert(first) + streaming.convert(second) == whole.convert(source)


class FakeNativeSocket:
    def __init__(self) -> None:
        self.sent: list[str | bytes] = []

    async def send(self, message: str | bytes) -> None:
        self.sent.append(message)

    async def recv(self) -> str | bytes:
        await asyncio.Future()
        raise AssertionError("unreachable")

    async def close(self) -> None:
        return None


def test_append_starts_native_turn_and_sends_framed_pcm16() -> None:
    async def exercise() -> None:
        socket = FakeNativeSocket()

        async def open_socket(_: str) -> FakeNativeSocket:
            return socket

        session = OpenAISession(settings())
        await session.open(open_socket)
        await websocket_event(session, session_update("de", 24_000))
        audio = b"\x00\x00" * 240
        await websocket_event(
            session,
            {
                "type": "input_audio_buffer.append",
                "audio": base64.b64encode(audio).decode("ascii"),
            },
        )

        start = json.loads(socket.sent[0])
        packet = decode_audio_packet(socket.sent[1])
        assert start == {"type": "start", "turnId": session.item_id, "language": "de"}
        assert packet.metadata == {
            "audioSequence": 0,
            "sampleRate": 16_000,
            "channels": 1,
            "format": "pcm_s16le",
            "frames": len(packet.audio) // 2,
        }
        await websocket_event(session, {"type": "input_audio_buffer.clear"})
        assert json.loads(socket.sent[-1]) == {"type": "reset"}
        assert not session.active_turn
        assert session.packet_sequence == 0

    asyncio.run(exercise())


def test_model_and_realtime_session_response_shapes() -> None:
    socket = FakeNativeSocket()

    async def open_socket(_: str) -> FakeNativeSocket:
        return socket

    app = create_app(settings(), open_socket)
    with TestClient(app) as client:
        models = client.get("/v1/models")
        assert models.json() == {
            "object": "list",
            "data": [
                {
                    "id": "nvidia/nemotron-3.5-asr-streaming-0.6b",
                    "object": "model",
                    "created": 0,
                    "owned_by": "realtimestt",
                }
            ],
        }
        with client.websocket_connect("/v1/realtime?intent=transcription") as websocket:
            created = websocket.receive_json()
            websocket.send_json(session_update())
            updated = websocket.receive_json()

    assert created["type"] == "session.created"
    assert "event_id" in created
    assert updated["type"] == "session.updated"
    assert updated["session"]["audio"]["input"]["transcription"]["language"] == "fr-CA"


def test_rest_transcription_accepts_multipart_upload_and_defaults_language(
    monkeypatch,
) -> None:
    observed: dict[str, object] = {}

    async def decode_upload(upload) -> bytes:
        observed["filename"] = upload.filename
        return b"\x00\x00"

    async def transcribe(_client, pcm16: bytes, language: str) -> str:
        observed["pcm16"] = pcm16
        observed["language"] = language
        return "hello"

    monkeypatch.setattr(openai_adapter, "decode_upload", decode_upload)
    monkeypatch.setattr(openai_adapter, "native_transcription", transcribe)

    with TestClient(create_app(settings())) as client:
        response = client.post(
            "/v1/audio/transcriptions",
            files={"file": ("sample.wav", b"audio", "audio/wav")},
            data={
                "model": "nvidia/nemotron-3.5-asr-streaming-0.6b",
                "response_format": "json",
            },
        )

    assert response.status_code == 200
    assert response.json() == {"text": "hello"}
    assert observed == {
        "filename": "sample.wav",
        "pcm16": b"\x00\x00",
        "language": "en",
    }
