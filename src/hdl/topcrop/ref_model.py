#!/usr/bin/env python3
"""Golden reference for nms_top5: 5x5 local maxima + greedy top-5 with r=8 exclusion."""
import random

W = H = 40

def local_maxima(g):
    """Strict local max over 5x5, raster-order tie-break, out-of-grid masked."""
    out = []
    for y in range(H):
        for x in range(W):
            v = g[y][x]
            if v == 0:
                continue
            ok = True
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    if dx == 0 and dy == 0:
                        continue
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < W and 0 <= ny < H):
                        continue
                    n = g[ny][nx]
                    precedes = (ny < y) or (ny == y and nx < x)
                    if precedes:
                        if not (v > n):
                            ok = False
                    else:
                        if not (v >= n):
                            ok = False
            if ok:
                out.append((v, x, y))      # appended in raster order
    return out

def near(x1, y1, x2, y2):
    return (x1 - x2) ** 2 + (y1 - y2) ** 2 < 64

def greedy_top5(cands):
    acc = []
    for _ in range(5):
        best = None
        for (v, x, y) in cands:          # raster order = RAM write order
            if any(near(x, y, ax, ay) for (_, ax, ay) in acc):
                continue
            if best is None or v > best[0]:   # strict > : first wins ties
                best = (v, x, y)
        if best is None:
            break
        acc.append(best)
    while len(acc) < 5:
        acc.append((0, 0, 0))
    return acc

def blank():
    return [[0] * W for _ in range(H)]

def make_frames():
    frames = []
    rng = random.Random(0xC0FFEE)

    # 1. sparse well-separated peaks on a low noise floor
    g = [[rng.randint(0, 50) for _ in range(W)] for _ in range(H)]
    for (x, y, v) in [(5, 5, 60000), (20, 8, 55000), (33, 15, 51000),
                      (10, 30, 48000), (30, 33, 45000), (18, 22, 40000)]:
        g[y][x] = v
    frames.append(("sparse_peaks", g))

    # 2. dense random field
    frames.append(("dense_random",
                   [[rng.randint(0, 65535) for _ in range(W)] for _ in range(H)]))

    # 3. large plateaus -- exercises the raster tie-break
    g = blank()
    for (x0, y0) in [(4, 4), (20, 6), (8, 25), (28, 28)]:
        for dy in range(4):
            for dx in range(4):
                g[y0 + dy][x0 + dx] = 30000
    frames.append(("plateaus", g))

    # 4. cluster inside the exclusion radius -- only one may survive
    g = blank()
    for (x, y, v) in [(20, 20, 60000), (23, 20, 59000), (20, 24, 58000),
                      (25, 25, 57000), (5, 5, 30000), (35, 35, 29000),
                      (5, 35, 28000), (35, 5, 27000)]:
        g[y][x] = v
    frames.append(("cluster", g))

    # 5. peaks hard against all four borders and corners
    g = blank()
    for (x, y, v) in [(0, 0, 65535), (39, 0, 65534), (0, 39, 65533),
                      (39, 39, 65532), (20, 0, 65531), (0, 20, 65530)]:
        g[y][x] = v
    frames.append(("borders", g))

    # 6. all zeros -- no candidates at all
    frames.append(("all_zero", blank()))

    # 7. single pixel
    g = blank(); g[17][23] = 1234
    frames.append(("single", g))

    # 8. uniform non-zero field -- one giant plateau
    frames.append(("uniform", [[777] * W for _ in range(H)]))

    # 9. worst-case candidate density: a local max every 3 px in both axes
    g = blank()
    for y in range(0, H, 3):
        for x in range(0, W, 3):
            g[y][x] = 1000 + x + y * W
    frames.append(("max_density", g))

    return frames

if __name__ == "__main__":
    frames = make_frames()
    with open("stim.txt", "w") as fs, open("expect.txt", "w") as fe:
        for (name, g) in frames:
            for y in range(H):
                for x in range(W):
                    fs.write("%d\n" % g[y][x])
            res = greedy_top5(local_maxima(g))
            fe.write(" ".join("%d %d %d" % (v, x, y) for (v, x, y) in res) + "\n")
            print("%-14s cands=%3d  ->  %s" %
                  (name, len(local_maxima(g)), res))
    print("\nwrote %d frames" % len(frames))
