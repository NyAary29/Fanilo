"""Montage de la vidéo de démonstration FANILO (1920x1080, 30 i/s, sous-titres anglais)."""
import glob, os, subprocess

RUSH = "/home/manana/Bureau/Fanilo/docs/video/rushes"
WORK = "/tmp/claude-1000/-home-manana-Bureau-Fanilo/e230a7e3-ba3c-4ebb-90e6-383cf5bc67fc/scratchpad/video"
OUT = "/home/manana/Bureau/Fanilo/docs/video/fanilo-demo.mp4"
FONT = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"
FONT_R = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
GREEN, CREAM = "0x1F5E3F", "0xF5F2EA"
W, H, FPS = 1920, 1080, 30


def web(name):
    return glob.glob(f"{RUSH}/{name}/*.webm")[0]


def esc(t):
    return t.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace(",", "\\,")


def run(args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args], check=True)


def title(path, dur, lines, bg=GREEN, fg="white"):
    draws = []
    for text, size, y, font in lines:
        draws.append(
            f"drawtext=fontfile={font}:text='{esc(text)}':fontsize={size}:fontcolor={fg}:"
            f"x=(w-text_w)/2:y={y}:alpha='min(1,t/0.8)'"
        )
    run(["-f", "lavfi", "-i", f"color=c={bg}:s={W}x{H}:r={FPS}:d={dur}",
         "-vf", ",".join(draws) + f",fade=t=out:st={dur-0.6}:d=0.6",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", str(FPS), path])


def phone(path, src, speed, label, sub, start=0.0, end=None):
    trim = f"trim=start={start}" + (f":end={end}" if end else "") + ",setpts=PTS-STARTPTS"
    vf = (
        f"[0:v]{trim},setpts=PTS/{speed},fps={FPS},scale=-2:960,"
        f"pad=iw+24:ih+24:12:12:color=0x1B1F1D[ph];"
        f"color=c={CREAM}:s={W}x{H}:r={FPS}[bg];"
        f"[bg]drawbox=x=0:y=0:w=760:h={H}:color={GREEN}:t=fill,"
        f"drawtext=fontfile={FONT}:text='{esc(label)}':fontsize=54:fontcolor=white:x=80:y=380,"
        f"drawtext=fontfile={FONT_R}:text='{esc(sub)}':fontsize=34:fontcolor=0xCFE9D8:x=80:y=470,"
        f"drawtext=fontfile={FONT}:text='FANILO':fontsize=40:fontcolor=white:x=80:y=80[bg2];"
        f"[bg2][ph]overlay=x=1000+(W-1000-w)/2:y=(H-h)/2:shortest=1,format=yuv420p"
    )
    run(["-i", src, "-filter_complex", vf, "-an", "-c:v", "libx264", "-r", str(FPS), path])


def screen(path, src, speed, start=0.0, end=None):
    trim = f"trim=start={start}" + (f":end={end}" if end else "") + ",setpts=PTS-STARTPTS"
    vf = f"{trim},setpts=PTS/{speed},fps={FPS},scale={W}:{H}:flags=lanczos,format=yuv420p"
    run(["-i", src, "-vf", vf, "-an", "-c:v", "libx264", "-r", str(FPS), path])


def dur(path):
    return float(subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]))


# (fichier, [(début relatif, fin relative, sous-titre)])
segments = []
os.makedirs(WORK, exist_ok=True)

s = f"{WORK}/01.mp4"
title(s, 7, [("FANILO", 150, 330, FONT), ("Fahasalamana ho an’ny rehetra", 48, 520, FONT_R),
             ("Health for everyone — by voice, in Malagasy", 44, 600, FONT_R)])
segments.append((s, [(0.5, 6.8, "FANILO — Health for everyone, by voice, in Malagasy.")]))

s = f"{WORK}/02.mp4"
phone(s, f"{RUSH}/scene2.mp4", 2.4, "Women & girls app", "Anonymous — no account, no name")
segments.append((s, [(0, 10, "No account. No name. Hanta, 16, simply asks her question in Malagasy."),
                     (10, 99, "She gets an answer drawn only from messages approved by health professionals.")]))

s = f"{WORK}/03.mp4"
screen(s, web("web_scene3"), 1.4, start=1.0)
segments.append((s, [(0, 99, "When a question needs a human, a counselor answers from the dashboard.")]))

s = f"{WORK}/04.mp4"
phone(s, f"{RUSH}/scene3_phone.mp4", 1.6, "Women & girls app", "The reply comes back — still anonymous", start=24.0)
segments.append((s, [(0, 99, "The reply comes back in the app. Still anonymous. Still private.")]))

s = f"{WORK}/05.mp4"
phone(s, f"{RUSH}/scene4a.mp4", 3.0, "Health worker app", "Works offline — consent first")
segments.append((s, [(0, 99, "Lova, a community health worker, registers Voahirana. Consent comes first — even without network.")]))

s = f"{WORK}/06.mp4"
phone(s, f"{RUSH}/scene4b.mp4", 2.5, "Health worker app", "Antenatal visits scheduled automatically")
segments.append((s, [(0, 99, "Her pregnancy is recorded. Antenatal visits and reminders are scheduled automatically.")]))

s = f"{WORK}/07.mp4"
phone(s, f"{RUSH}/scene5_phone.mp4", 2.2, "Health worker app", "A danger sign? One tap")
segments.append((s, [(0, 99, "During a visit, Lova reports a danger sign. One tap alerts the health centre.")]))

s = f"{WORK}/08.mp4"
screen(s, web("web_scene5"), 1.2)
segments.append((s, [(0, 99, "A named person receives the alert, with a deadline and a backup — and acknowledges it.")]))

s = f"{WORK}/09.mp4"
screen(s, web("web_scene6"), 1.0, start=3.0)
segments.append((s, [(0, 99, "Health centres follow pregnancies, missed visits, alerts and referrals — anonymised data only.")]))

s = f"{WORK}/10.mp4"
title(s, 6, [("AI proposes.", 90, 380, FONT), ("Health professionals decide.", 90, 510, FONT)])
segments.append((s, [(0.5, 5.8, "FANILO never diagnoses and never replaces a health worker.")]))

s = f"{WORK}/11.mp4"
title(s, 5, [("FANILO", 120, 390, FONT), ("Havanana Impact × Creatic", 52, 560, FONT_R)])
segments.append((s, []))

# Sous-titres (ASS) sur la ligne de temps complète
def ts(t):
    h, rem = divmod(t, 3600); m, sec = divmod(rem, 60)
    return f"{int(h)}:{int(m):02d}:{sec:05.2f}"

events, t0 = [], 0.0
for path, subs in segments:
    d = dur(path)
    for a, b, text in subs:
        events.append(f"Dialogue: 0,{ts(t0 + a)},{ts(t0 + min(b, d - 0.2))},Sub,,0,0,0,,{text}")
    t0 += d
ass = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Sub,Noto Sans,46,&H00FFFFFF,&H00FFFFFF,&H00000000,&HB4141414,-1,0,0,0,100,100,0,0,3,14,0,2,160,160,60,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
""" + "\n".join(events) + "\n"
open(f"{WORK}/subs.ass", "w").write(ass)

with open(f"{WORK}/list.txt", "w") as f:
    for path, _ in segments:
        f.write(f"file '{path}'\n")
run(["-f", "concat", "-safe", "0", "-i", f"{WORK}/list.txt",
     "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
     "-vf", f"ass={WORK}/subs.ass", "-c:v", "libx264", "-crf", "20", "-preset", "medium",
     "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", "-movflags", "+faststart", OUT])
print("OK", OUT, round(dur(OUT), 1), "s")
for path, subs in segments:
    print(os.path.basename(path), round(dur(path), 1))
