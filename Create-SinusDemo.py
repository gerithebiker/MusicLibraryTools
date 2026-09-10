import numpy as np
import wave
from pathlib import Path

FS = 44100
DUR = 10.0          # seconds
AMP = 0.9           # near full scale, makes glitches obvious
OUT = Path("bit_error_wavs")
OUT.mkdir(exist_ok=True)

rng = np.random.default_rng(20260201)

def write_wav_int16(path: Path, x_int16: np.ndarray):
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)  # int16
        wf.setframerate(FS)
        wf.writeframes(x_int16.tobytes())

def tone_int16(freq_hz: float, dur_s: float, amp: float = AMP) -> np.ndarray:
    t = np.arange(int(FS * dur_s)) / FS
    x = amp * np.sin(2*np.pi*freq_hz*t)
    return np.clip(x, -1.0, 1.0).astype(np.float64) * 32767.0

def as_int16(x) -> np.ndarray:
    return np.round(x).astype(np.int16)

def flip_bit_at_indices(x_int16: np.ndarray, idxs: np.ndarray, bit: int) -> np.ndarray:
    u = x_int16.view(np.uint16).copy()
    u[idxs] ^= (1 << bit)
    return u.view(np.int16)

def flip_bit_with_probability(x_int16: np.ndarray, bit: int, p: float) -> np.ndarray:
    u = x_int16.view(np.uint16).copy()
    mask = rng.random(len(u)) < p
    u[mask] ^= (1 << bit)
    return u.view(np.int16)

for F in (440, 880):
    base = as_int16(tone_int16(F, DUR))
    n = len(base)

    # 0) clean
    write_wav_int16(OUT / f"{F}Hz_clean.wav", base)

    # 1) Sparse upper-bit glitches: BIT15, 3 glitches/sec (VERY audible clicks)
    idxs = []
    for sec in range(int(DUR)):
        idxs.extend((sec*FS + rng.integers(0, FS, size=3)).tolist())
    idxs = np.array([i for i in idxs if i < n], dtype=np.int64)
    sparse_bit15 = flip_bit_at_indices(base, idxs, bit=15)
    write_wav_int16(OUT / f"{F}Hz_sparse_3persec_BIT15.wav", sparse_bit15)

    # 2) Dense upper-bit damage: BIT15, flip ~0.7% of samples (harsh distortion)
    dense_bit15 = flip_bit_with_probability(base, bit=15, p=0.007)
    write_wav_int16(OUT / f"{F}Hz_dense_mask0p7pct_BIT15.wav", dense_bit15)

    # 3) Silence then LSB noise: 5s silence + 5s tone, flip LSB on 10% samples
    silence = np.zeros(int(FS*5), dtype=np.int16)
    tone5 = as_int16(tone_int16(F, 5.0))
    lsb_noisy = flip_bit_with_probability(tone5, bit=0, p=0.10)
    sil_then_noise = np.concatenate([silence, lsb_noisy])
    write_wav_int16(OUT / f"{F}Hz_silence5s_then_LSBmask10pct.wav", sil_then_noise)

print("Done. Files written to:", OUT.resolve())
