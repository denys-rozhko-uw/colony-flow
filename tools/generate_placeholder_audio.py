"""Generate original, simple WAV placeholders for the prototype."""

import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050


def write_tone(name: str, notes: list[tuple[float, float]], volume: float = 0.26) -> None:
    samples: list[int] = []
    for frequency, duration in notes:
        count = int(RATE * duration)
        fade = min(int(RATE * 0.025), count // 4)
        for index in range(count):
            attack = min(1.0, index / max(1, fade))
            release = min(1.0, (count - index - 1) / max(1, fade))
            envelope = min(attack, release)
            phase = 2.0 * math.pi * frequency * index / RATE
            signal = math.sin(phase) * 0.85 + math.sin(phase * 2.0) * 0.15
            samples.append(int(32767 * volume * envelope * signal))
    with wave.open(str(ROOT / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(struct.pack("<" + "h" * len(samples), *samples))


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    write_tone("select.wav", [(500, 0.08), (650, 0.06)])
    write_tone("reject.wav", [(220, 0.13)])
    write_tone("pickup.wav", [(730, 0.05)])
    write_tone("deliver.wav", [(620, 0.07)])
    write_tone("win.wav", [(440, 0.12), (550, 0.12), (660, 0.12), (880, 0.24)])
    write_tone("lose.wav", [(330, 0.15), (247, 0.20)])
    write_tone("music.wav", [(220, 0.35), (330, 0.35), (262, 0.35), (392, 0.35)] * 4, volume=0.08)


if __name__ == "__main__":
    main()
