import math
import struct
import wave

SAMPLE_RATE = 44100

def create_wav(filename, samples):
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1)        # mono
        wav.setsampwidth(2)        # 16-bit
        wav.setframerate(SAMPLE_RATE)
        raw_data = bytearray()
        for s in samples:
            # clamp between -1.0 and 1.0
            clamped = max(-1.0, min(1.0, s))
            val = int(clamped * 32767.0)
            raw_data.extend(struct.pack('<h', val))
        wav.writeframes(raw_data)

def generate_chirp():
    # Ben Burtt WALL-E style inquisitive chirp:
    # Blend of fundamental sine + subtle pitch modulated square/triangle + quick frequency glissando
    duration = 0.22
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # Upward sweep: 550 Hz -> 1450 Hz
        freq = 550 + 900 * (t / duration) ** 1.3
        
        # Envelope: fast attack (15ms), smooth decay
        if t < 0.015:
            env = t / 0.015
        else:
            env = math.exp(-6.5 * (t - 0.015))
            
        # Ben Burtt formula: primary sine + warm 2nd harmonic + slight ring-mod buzz
        phase = 2 * math.pi * freq * t
        primary = math.sin(phase)
        harmonic2 = 0.35 * math.sin(2 * phase)
        subtle_buzz = 0.15 * math.copysign(1.0, math.sin(3 * phase)) # soft square harmonic
        
        sample = (primary + harmonic2 + subtle_buzz) * 0.75 * env
        samples.append(sample)
        
    create_wav('assets/audio/pip_chirp.wav', samples)

def generate_happy():
    # Cheerful ascending tri-tone melodic warble (WALL-E delighted beep)
    # Notes: C6 (1046.5 Hz) -> E6 (1318.5 Hz) -> G6 (1567.9 Hz) with servo flutter
    samples = []
    notes = [
        (1046.5, 0.08),
        (1318.5, 0.09),
        (1567.9, 0.18),
    ]
    
    for freq, dur in notes:
        n_samples = int(SAMPLE_RATE * dur)
        for i in range(n_samples):
            t = i / SAMPLE_RATE
            # slight vibrato / servo modulation
            vib = math.sin(2 * math.pi * 32 * t) * (18.0 * (1 - t / dur))
            f = freq + vib
            
            if t < 0.01:
                env = t / 0.01
            else:
                env = math.exp(-7.0 * (t - 0.01))
                
            phase = 2 * math.pi * f * t
            val = (0.7 * math.sin(phase) + 0.2 * math.sin(2 * phase) + 0.1 * math.sin(3 * phase)) * env
            samples.append(val)
            
    create_wav('assets/audio/pip_happy.wav', samples)

def generate_thinking():
    # Inquisitive low-to-high oscillation with ring modulation
    duration = 0.28
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # Wobble between 620 Hz and 780 Hz
        freq = 700 + 80 * math.sin(2 * math.pi * 14 * t)
        
        env = math.sin(math.pi * (t / duration)) # bell curve
        phase = 2 * math.pi * freq * t
        val = 0.8 * math.sin(phase) * env
        samples.append(val)
        
    create_wav('assets/audio/pip_thinking.wav', samples)

def generate_blip():
    # Quick mechanical camera shutter / solenoid tactile click
    duration = 0.035
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    
    import random
    rng = random.Random(42)
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-85 * t)
        # Short metallic transient click + brief resonant pop (1800 Hz)
        metal_noise = rng.uniform(-0.4, 0.4)
        pop = 0.6 * math.sin(2 * math.pi * 1800 * t)
        sample = (metal_noise + pop) * env
        samples.append(sample)
        
    create_wav('assets/audio/pip_blip.wav', samples)

def generate_sleep():
    # Descending sleepy power-down sigh (WALL-E shutting down for rest)
    duration = 0.45
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # Glissando down: 900 Hz -> 220 Hz
        freq = 900 * math.exp(-3.2 * t)
        env = math.exp(-4.2 * t)
        phase = 2 * math.pi * freq * t
        val = (0.75 * math.sin(phase) + 0.25 * math.sin(phase * 0.5)) * env
        samples.append(val)
        
    create_wav('assets/audio/pip_sleep.wav', samples)

if __name__ == '__main__':
    generate_chirp()
    generate_happy()
    generate_thinking()
    generate_blip()
    generate_sleep()
    print("All WALL-E mechanical robot audio textures synthesized successfully!")
