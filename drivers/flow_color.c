/*
 * flow_color — Display accumulated optical flow on DisplayPort
 *
 * Reads frames from /dev/flow0, accumulates flow vectors over 5
 * timesteps (1-5), scales by a calibration factor, and renders
 * using the Middlebury optical flow color scheme via DRM/KMS.
 * Displays stats overlay: avg/max u/v, max magnitude, FPS, power.
 *
 * Packet format (64 bits per vector):
 *   [63:40] = zeros
 *   [39:36] = timestep  (4 bits, 1-5)
 *   [35:27] = fh_x      (9 bits, unsigned, 0-319)
 *   [26:18] = fh_y      (9 bits, unsigned, 0-319)
 *   [17:9]  = fh_u      (9 bits, signed)
 *   [8:0]   = fh_v      (9 bits, signed)
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <getopt.h>
#include <time.h>
#include <math.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

/* ------------------------------------------------------------------ */
/*  Constants                                                         */
/* ------------------------------------------------------------------ */

#define FLOW_DEV        "/dev/flow0"
#define DRM_DEV         "/dev/dri/card0"
#define MAX_FRAME_SIZE  (1024 * 1024)
#define BYTES_PER_VEC   8

#define SRC_W           320
#define SRC_H           320
#define BPP             3
#define SCALE           3
#define SCALED_W        (SRC_W * SCALE)
#define SCALED_H        (SRC_H * SCALE)

#define NUM_TIMESTEPS   5

#define DEFAULT_FLOW_WEIGHT 0.01684998907148838

#define FONT_W          5
#define FONT_H          7
#define TEXT_SCALE      3
#define TEXT_MARGIN     10

#define DEFAULT_SNAPSHOT_INTERVAL 0
#define DEFAULT_SNAPSHOT_DIR      "snapshots"

/* ------------------------------------------------------------------ */
/*  DRM buffer                                                        */
/* ------------------------------------------------------------------ */

typedef struct {
    uint32_t handle;
    uint32_t fb_id;
    uint32_t stride;
    uint32_t size;
    uint8_t *map;
} drm_buf_t;

typedef struct {
    int          fd;
    uint32_t     conn_id;
    uint32_t     crtc_id;
    drmModeModeInfo mode;
    drm_buf_t    bufs[2];
    int          front;
} flow_drm_ctx_t;

/* ------------------------------------------------------------------ */
/*  Embedded 5x7 bitmap font — full lowercase + digits + symbols      */
/* ------------------------------------------------------------------ */

/* Index: 0=space, 1-26=a-z, 27-36=0-9, 37='-', 38='.', 39=':', 40='=' */
static const uint8_t font_glyphs[][FONT_H] = {
    /* 0  ' ' */ {0x00,0x00,0x00,0x00,0x00,0x00,0x00},
    /* 1  'a' */ {0x00,0x00,0x0E,0x01,0x0F,0x11,0x0F},
    /* 2  'b' */ {0x10,0x10,0x16,0x19,0x11,0x11,0x1E},
    /* 3  'c' */ {0x00,0x00,0x0E,0x10,0x10,0x11,0x0E},
    /* 4  'd' */ {0x01,0x01,0x0D,0x13,0x11,0x11,0x0F},
    /* 5  'e' */ {0x00,0x00,0x0E,0x11,0x1F,0x10,0x0E},
    /* 6  'f' */ {0x02,0x05,0x04,0x0E,0x04,0x04,0x04},
    /* 7  'g' */ {0x00,0x00,0x0F,0x11,0x0F,0x01,0x0E},
    /* 8  'h' */ {0x10,0x10,0x16,0x19,0x11,0x11,0x11},
    /* 9  'i' */ {0x04,0x00,0x0C,0x04,0x04,0x04,0x0E},
    /* 10 'j' */ {0x02,0x00,0x06,0x02,0x02,0x12,0x0C},
    /* 11 'k' */ {0x10,0x10,0x12,0x14,0x18,0x14,0x12},
    /* 12 'l' */ {0x0C,0x04,0x04,0x04,0x04,0x04,0x0E},
    /* 13 'm' */ {0x00,0x00,0x1A,0x15,0x15,0x11,0x11},
    /* 14 'n' */ {0x00,0x00,0x16,0x19,0x11,0x11,0x11},
    /* 15 'o' */ {0x00,0x00,0x0E,0x11,0x11,0x11,0x0E},
    /* 16 'p' */ {0x00,0x00,0x1E,0x11,0x1E,0x10,0x10},
    /* 17 'q' */ {0x00,0x00,0x0D,0x13,0x0F,0x01,0x01},
    /* 18 'r' */ {0x00,0x00,0x16,0x19,0x10,0x10,0x10},
    /* 19 's' */ {0x00,0x00,0x0F,0x10,0x0E,0x01,0x1E},
    /* 20 't' */ {0x04,0x04,0x0E,0x04,0x04,0x05,0x02},
    /* 21 'u' */ {0x00,0x00,0x11,0x11,0x11,0x13,0x0D},
    /* 22 'v' */ {0x00,0x00,0x11,0x11,0x11,0x0A,0x04},
    /* 23 'w' */ {0x00,0x00,0x11,0x11,0x15,0x15,0x0A},
    /* 24 'x' */ {0x00,0x00,0x11,0x0A,0x04,0x0A,0x11},
    /* 25 'y' */ {0x00,0x00,0x11,0x11,0x0F,0x01,0x0E},
    /* 26 'z' */ {0x00,0x00,0x1F,0x02,0x04,0x08,0x1F},
    /* 27 '0' */ {0x0E,0x11,0x13,0x15,0x19,0x11,0x0E},
    /* 28 '1' */ {0x04,0x0C,0x04,0x04,0x04,0x04,0x0E},
    /* 29 '2' */ {0x0E,0x11,0x01,0x02,0x04,0x08,0x1F},
    /* 30 '3' */ {0x0E,0x11,0x01,0x06,0x01,0x11,0x0E},
    /* 31 '4' */ {0x02,0x06,0x0A,0x12,0x1F,0x02,0x02},
    /* 32 '5' */ {0x1F,0x10,0x1E,0x01,0x01,0x11,0x0E},
    /* 33 '6' */ {0x06,0x08,0x10,0x1E,0x11,0x11,0x0E},
    /* 34 '7' */ {0x1F,0x01,0x02,0x04,0x08,0x08,0x08},
    /* 35 '8' */ {0x0E,0x11,0x11,0x0E,0x11,0x11,0x0E},
    /* 36 '9' */ {0x0E,0x11,0x11,0x0F,0x01,0x02,0x0C},
    /* 37 '-' */ {0x00,0x00,0x00,0x1F,0x00,0x00,0x00},
    /* 38 '.' */ {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C},
    /* 39 ':' */ {0x00,0x0C,0x0C,0x00,0x0C,0x0C,0x00},
    /* 40 '=' */ {0x00,0x00,0x1F,0x00,0x1F,0x00,0x00},
};

static int char_to_glyph(char c)
{
    if (c == ' ')  return 0;
    if (c >= 'a' && c <= 'z') return 1 + (c - 'a');
    if (c >= '0' && c <= '9') return 27 + (c - '0');
    if (c == '-')  return 37;
    if (c == '.')  return 38;
    if (c == ':')  return 39;
    if (c == '=')  return 40;
    return 0;
}

static void draw_char(drm_buf_t *fb, uint32_t disp_w, uint32_t disp_h,
                      int px, int py, char c,
                      uint8_t r, uint8_t g, uint8_t b)
{
    int gi = char_to_glyph(c);
    const uint8_t *glyph = font_glyphs[gi];

    for (int row = 0; row < FONT_H; row++) {
        uint8_t bits = glyph[row];
        for (int col = 0; col < FONT_W; col++) {
            if (!(bits & (1 << (FONT_W - 1 - col))))
                continue;
            for (int sy = 0; sy < TEXT_SCALE; sy++) {
                int dy = py + row * TEXT_SCALE + sy;
                if (dy < 0 || (uint32_t)dy >= disp_h) continue;
                uint8_t *rowp = fb->map + dy * fb->stride;
                for (int sx = 0; sx < TEXT_SCALE; sx++) {
                    int dx = px + col * TEXT_SCALE + sx;
                    if (dx < 0 || (uint32_t)dx >= disp_w) continue;
                    uint8_t *p = rowp + dx * BPP;
                    p[0] = b; p[1] = g; p[2] = r;
                }
            }
        }
    }
}

static void draw_string(drm_buf_t *fb, uint32_t disp_w, uint32_t disp_h,
                        int px, int py, const char *str,
                        uint8_t r, uint8_t g, uint8_t b)
{
    int char_w = FONT_W * TEXT_SCALE + TEXT_SCALE;
    int x = px;
    while (*str) {
        draw_char(fb, disp_w, disp_h, x, py, *str, r, g, b);
        x += char_w;
        str++;
    }
}

static void fmt_float(float val, char *buf, int buflen, int decimals)
{
    int neg = (val < 0);
    if (neg) val = -val;

    int ipart = (int)val;
    float fpart = val - (float)ipart;

    char tmp[32];
    int ti = 0;
    if (ipart == 0) {
        tmp[ti++] = '0';
    } else {
        while (ipart > 0 && ti < 20) {
            tmp[ti++] = '0' + (ipart % 10);
            ipart /= 10;
        }
    }

    int bi = 0;
    if (neg && bi < buflen - 1) buf[bi++] = '-';
    for (int i = ti - 1; i >= 0 && bi < buflen - 1; i--)
        buf[bi++] = tmp[i];

    if (decimals > 0 && bi < buflen - 1) {
        buf[bi++] = '.';
        for (int d = 0; d < decimals && bi < buflen - 1; d++) {
            fpart *= 10.0f;
            int digit = (int)fpart;
            buf[bi++] = '0' + digit;
            fpart -= digit;
        }
    }
    buf[bi] = '\0';
}

static void fmt_int(int val, char *buf, int buflen)
{
    int neg = (val < 0);
    if (neg) val = -val;

    char tmp[32];
    int ti = 0;
    if (val == 0) {
        tmp[ti++] = '0';
    } else {
        while (val > 0 && ti < 20) {
            tmp[ti++] = '0' + (val % 10);
            val /= 10;
        }
    }

    int bi = 0;
    if (neg && bi < buflen - 1) buf[bi++] = '-';
    for (int i = ti - 1; i >= 0 && bi < buflen - 1; i--)
        buf[bi++] = tmp[i];
    buf[bi] = '\0';
}

/* ------------------------------------------------------------------ */
/*  Power reading via xmutil                                          */
/* ------------------------------------------------------------------ */

static int read_power_mw(void)
{
    FILE *fp = popen("xmutil xlnx_platformstats -p 2>/dev/null", "r");
    if (!fp) return -1;

    char line[256];
    int power = -1;

    while (fgets(line, sizeof(line), fp)) {
        if (strstr(line, "SOM total power")) {
            /* Parse "SOM total power   :   3680 mW" */
            char *colon = strchr(line, ':');
            if (colon)
                power = atoi(colon + 1);
            break;
        }
    }
    pclose(fp);
    return power;
}

/* ------------------------------------------------------------------ */
/*  Signal handling                                                   */
/* ------------------------------------------------------------------ */

static volatile int g_quit = 0;

static void on_signal(int sig)
{
    (void)sig;
    g_quit = 1;
}

/* ------------------------------------------------------------------ */
/*  Sign extension                                                    */
/* ------------------------------------------------------------------ */

static inline int sign_extend_9(unsigned int val)
{
    if (val & 0x100)
        return (int)(val | 0xFFFFFE00);
    return (int)val;
}

/* ------------------------------------------------------------------ */
/*  Middlebury color wheel                                            */
/* ------------------------------------------------------------------ */

#define NCOLS 55

static int colorwheel[NCOLS][3];
static int ncols = 0;

static void make_colorwheel(void)
{
    int nRY = 15, nYG = 6, nGC = 4, nCB = 11, nBM = 13, nMR = 6;
    int idx = 0;
    int i;

    for (i = 0; i < nRY; i++) {
        colorwheel[idx][0] = 255;
        colorwheel[idx][1] = 255 * i / nRY;
        colorwheel[idx][2] = 0;
        idx++;
    }
    for (i = 0; i < nYG; i++) {
        colorwheel[idx][0] = 255 - 255 * i / nYG;
        colorwheel[idx][1] = 255;
        colorwheel[idx][2] = 0;
        idx++;
    }
    for (i = 0; i < nGC; i++) {
        colorwheel[idx][0] = 0;
        colorwheel[idx][1] = 255;
        colorwheel[idx][2] = 255 * i / nGC;
        idx++;
    }
    for (i = 0; i < nCB; i++) {
        colorwheel[idx][0] = 0;
        colorwheel[idx][1] = 255 - 255 * i / nCB;
        colorwheel[idx][2] = 255;
        idx++;
    }
    for (i = 0; i < nBM; i++) {
        colorwheel[idx][0] = 255 * i / nBM;
        colorwheel[idx][1] = 0;
        colorwheel[idx][2] = 255;
        idx++;
    }
    for (i = 0; i < nMR; i++) {
        colorwheel[idx][0] = 255;
        colorwheel[idx][1] = 0;
        colorwheel[idx][2] = 255 - 255 * i / nMR;
        idx++;
    }
    ncols = idx;
}

static void flow_to_rgb(float u, float v,
                        uint8_t *r, uint8_t *g, uint8_t *b)
{
    float rad = sqrtf(u * u + v * v);
    float a = atan2f(-v, -u) / (float)M_PI;

    float fk = (a + 1.0f) / 2.0f * (float)(ncols - 1);
    int k0 = (int)floorf(fk);
    int k1 = k0 + 1;
    if (k1 >= ncols) k1 = 0;
    float f = fk - (float)k0;

    if (k0 < 0) k0 = 0;
    if (k0 >= ncols) k0 = ncols - 1;

    uint8_t rgb[3];
    for (int ch = 0; ch < 3; ch++) {
        float col0 = colorwheel[k0][ch] / 255.0f;
        float col1 = colorwheel[k1][ch] / 255.0f;
        float col = (1.0f - f) * col0 + f * col1;

        if (rad <= 1.0f)
            col = 1.0f - rad * (1.0f - col);
        else
            col *= 0.75f;

        rgb[ch] = (uint8_t)floorf(255.0f * col);
    }
    *r = rgb[0];
    *g = rgb[1];
    *b = rgb[2];
}

/* ------------------------------------------------------------------ */
/*  DRM setup                                                         */
/* ------------------------------------------------------------------ */

static int find_display(flow_drm_ctx_t *ctx, uint32_t req_w, uint32_t req_h)
{
    drmModeRes *res = drmModeGetResources(ctx->fd);
    if (!res) return -1;

    for (int i = 0; i < res->count_connectors; i++) {
        drmModeConnector *conn =
            drmModeGetConnector(ctx->fd, res->connectors[i]);
        if (!conn) continue;
        if (conn->connection != DRM_MODE_CONNECTED ||
            conn->count_modes == 0) {
            drmModeFreeConnector(conn);
            continue;
        }

        drmModeModeInfo *best = NULL;
        for (int m = 0; m < conn->count_modes; m++) {
            if (conn->modes[m].hdisplay == req_w &&
                conn->modes[m].vdisplay == req_h) {
                best = &conn->modes[m];
                break;
            }
        }
        if (!best) {
            for (int m = 0; m < conn->count_modes; m++) {
                if (conn->modes[m].type & DRM_MODE_TYPE_PREFERRED) {
                    best = &conn->modes[m];
                    break;
                }
            }
        }
        if (!best) best = &conn->modes[0];

        drmModeEncoder *enc = conn->encoder_id ?
            drmModeGetEncoder(ctx->fd, conn->encoder_id) : NULL;
        if (!enc) {
            for (int e = 0; e < conn->count_encoders; e++) {
                enc = drmModeGetEncoder(ctx->fd, conn->encoders[e]);
                if (enc) break;
            }
        }
        if (!enc) { drmModeFreeConnector(conn); continue; }

        uint32_t crtc_id = enc->crtc_id;
        if (!crtc_id) {
            for (int c = 0; c < res->count_crtcs; c++) {
                if (enc->possible_crtcs & (1 << c)) {
                    crtc_id = res->crtcs[c];
                    break;
                }
            }
        }
        drmModeFreeEncoder(enc);
        if (!crtc_id) { drmModeFreeConnector(conn); continue; }

        ctx->conn_id = conn->connector_id;
        ctx->crtc_id = crtc_id;
        ctx->mode    = *best;

        fprintf(stderr, "Display: %ux%u@%u\n",
                best->hdisplay, best->vdisplay, best->vrefresh);

        drmModeFreeConnector(conn);
        drmModeFreeResources(res);
        return 0;
    }

    drmModeFreeResources(res);
    return -1;
}

static int create_fb(int fd, uint32_t w, uint32_t h, drm_buf_t *fb)
{
    struct drm_mode_create_dumb creq = {
        .width = w, .height = h, .bpp = 24,
    };
    if (drmIoctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq) < 0) return -1;
    fb->handle = creq.handle;
    fb->stride = creq.pitch;
    fb->size   = creq.size;

    uint32_t handles[4] = { fb->handle };
    uint32_t strides[4] = { fb->stride };
    uint32_t offsets[4] = { 0 };
    uint32_t fmt = 'R' | ('G' << 8) | ('2' << 16) | ('4' << 24);

    if (drmModeAddFB2(fd, w, h, fmt,
                      handles, strides, offsets, &fb->fb_id, 0) < 0)
        return -1;

    struct drm_mode_map_dumb mreq = { .handle = fb->handle };
    if (drmIoctl(fd, DRM_IOCTL_MODE_MAP_DUMB, &mreq) < 0) return -1;

    fb->map = mmap(NULL, fb->size, PROT_READ | PROT_WRITE,
                   MAP_SHARED, fd, mreq.offset);
    if (fb->map == MAP_FAILED) return -1;
    memset(fb->map, 0, fb->size);
    return 0;
}

static void destroy_fb(int fd, drm_buf_t *fb)
{
    if (fb->map && fb->map != MAP_FAILED)
        munmap(fb->map, fb->size);
    if (fb->fb_id) drmModeRmFB(fd, fb->fb_id);
    if (fb->handle) {
        struct drm_mode_destroy_dumb d = { .handle = fb->handle };
        drmIoctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &d);
    }
}

/* ------------------------------------------------------------------ */
/*  Accumulation                                                      */
/* ------------------------------------------------------------------ */

static float acc_u[SRC_W * SRC_H];
static float acc_v[SRC_W * SRC_H];

static void acc_reset(void)
{
    memset(acc_u, 0, sizeof(acc_u));
    memset(acc_v, 0, sizeof(acc_v));
}

static int acc_add_frame(const uint8_t *data, size_t len)
{
    int n_vectors = len / BYTES_PER_VEC;
    int timestep = -1;

    for (int i = 0; i < n_vectors; i++) {
        uint64_t word;
        memcpy(&word, data + i * BYTES_PER_VEC, sizeof(word));

        unsigned int ts  = (word >> 36) & 0xF;
        unsigned int fh_x = (word >> 27) & 0x1FF;
        unsigned int fh_y = (word >> 18) & 0x1FF;
        int fh_u = sign_extend_9((word >> 9) & 0x1FF);
        int fh_v = sign_extend_9(word & 0x1FF);

        if (timestep < 0)
            timestep = ts;

        if (fh_x < SRC_W && fh_y < SRC_H) {
            int idx = fh_y * SRC_W + fh_x;
            acc_u[idx] += (float)fh_u;
            acc_v[idx] += (float)fh_v;
        }
    }
    return timestep;
}

/* ------------------------------------------------------------------ */
/*  Render flow + stats overlay                                       */
/* ------------------------------------------------------------------ */

static void render_flow(drm_buf_t *fb, uint32_t disp_w, uint32_t disp_h,
                        float weight, float fps, int power_mw)
{
    memset(fb->map, 0, fb->size);

    float max_mag = 0.0f;
    float scaled_u[SRC_W * SRC_H];
    float scaled_v[SRC_W * SRC_H];
    double sum_u = 0.0, sum_v = 0.0;
    int count = 0;
    float extreme_u = 0.0f;  /* u with max |u| */
    float extreme_v = 0.0f;  /* v with max |v| */
    float max_abs_u = 0.0f;
    float max_abs_v = 0.0f;

    for (int i = 0; i < SRC_W * SRC_H; i++) {
        scaled_u[i] = acc_u[i] * weight;
        scaled_v[i] = acc_v[i] * weight;

        float au = fabsf(scaled_u[i]);
        float av = fabsf(scaled_v[i]);
        float mag = sqrtf(scaled_u[i] * scaled_u[i] +
                          scaled_v[i] * scaled_v[i]);

        if (mag > max_mag)
            max_mag = mag;

        if (au > max_abs_u) {
            max_abs_u = au;
            extreme_u = scaled_u[i];
        }
        if (av > max_abs_v) {
            max_abs_v = av;
            extreme_v = scaled_v[i];
        }

        if (au > 1e-9f || av > 1e-9f) {
            sum_u += scaled_u[i];
            sum_v += scaled_v[i];
            count++;
        }
    }

    /* Pre-normalize */
    float epsilon = 1e-5f;
    float norm = max_mag * 0.4f + epsilon;

    for (int i = 0; i < SRC_W * SRC_H; i++) {
        scaled_u[i] /= norm;
        scaled_v[i] /= norm;
    }

    /* Centering offsets */
    uint32_t off_x = (disp_w > SCALED_W) ? (disp_w - SCALED_W) / 2 : 0;
    uint32_t off_y = (disp_h > SCALED_H) ? (disp_h - SCALED_H) / 2 : 0;

    /* Render flow field */
    for (uint32_t sy = 0; sy < SRC_H; sy++) {
        for (uint32_t sx = 0; sx < SRC_W; sx++) {
            int idx = sy * SRC_W + sx;
            float u = scaled_u[idx];
            float v = scaled_v[idx];

            if (fabsf(u) < 1e-6f && fabsf(v) < 1e-6f)
                continue;

            uint8_t r, g, b;
            flow_to_rgb(u, v, &r, &g, &b);

            for (int dy = 0; dy < SCALE; dy++) {
                uint32_t py = off_y + sy * SCALE + dy;
                if (py >= disp_h) continue;
                uint8_t *row = fb->map + py * fb->stride;

                for (int dx = 0; dx < SCALE; dx++) {
                    uint32_t px = off_x + sx * SCALE + dx;
                    if (px >= disp_w) continue;

                    uint8_t *p = row + px * BPP;
                    p[0] = b;
                    p[1] = g;
                    p[2] = r;
                }
            }
        }
    }

    /* ---- Stats overlay ---- */
    float avg_u = count > 0 ? (float)(sum_u / count) : 0.0f;
    float avg_v = count > 0 ? (float)(sum_v / count) : 0.0f;

    char line[64], vbuf[32];
    int line_h = FONT_H * TEXT_SCALE + TEXT_SCALE * 2;
    int y = TEXT_MARGIN;

    /* max mag */
    fmt_float(max_mag, vbuf, sizeof(vbuf), 3);
    snprintf(line, sizeof(line), "max mag=%s", vbuf);
    draw_string(fb, disp_w, disp_h, TEXT_MARGIN, y, line, 255, 255, 255);
    y += line_h;

    /* max u */
    fmt_float(extreme_u, vbuf, sizeof(vbuf), 3);
    snprintf(line, sizeof(line), "max u=%s", vbuf);
    draw_string(fb, disp_w, disp_h, TEXT_MARGIN, y, line, 255, 255, 255);
    y += line_h;

    /* max v */
    fmt_float(extreme_v, vbuf, sizeof(vbuf), 3);
    snprintf(line, sizeof(line), "max v=%s", vbuf);
    draw_string(fb, disp_w, disp_h, TEXT_MARGIN, y, line, 255, 255, 255);
    y += line_h;

    /* avg u */
    fmt_float(avg_u, vbuf, sizeof(vbuf), 3);
    snprintf(line, sizeof(line), "avg u=%s", vbuf);
    draw_string(fb, disp_w, disp_h, TEXT_MARGIN, y, line, 255, 255, 255);
    y += line_h;

    /* avg v */
    fmt_float(avg_v, vbuf, sizeof(vbuf), 3);
    snprintf(line, sizeof(line), "avg v=%s", vbuf);
    draw_string(fb, disp_w, disp_h, TEXT_MARGIN, y, line, 255, 255, 255);
    y += line_h;

    /* fps */
    fmt_float(fps, vbuf, sizeof(vbuf), 1);
    snprintf(line, sizeof(line), "fps=%s", vbuf);
    draw_string(fb, disp_w, disp_h, TEXT_MARGIN, y, line, 0, 255, 0);
    y += line_h;

    /* power */
    if (power_mw > 0) {
        fmt_int(power_mw, vbuf, sizeof(vbuf));
        snprintf(line, sizeof(line), "power=%s mw", vbuf);
        draw_string(fb, disp_w, disp_h, TEXT_MARGIN, y, line, 255, 200, 0);
    }
}


/* ------------------------------------------------------------------ */
/*  Snapshot saving                                                   */
/* ------------------------------------------------------------------ */

static int ensure_dir_exists(const char *path)
{
    struct stat st;
    if (stat(path, &st) == 0) {
        if (S_ISDIR(st.st_mode))
            return 0;
        errno = ENOTDIR;
        return -1;
    }

    if (mkdir(path, 0755) == 0)
        return 0;

    if (errno == EEXIST)
        return 0;

    return -1;
}

static int save_fb_to_ppm(const drm_buf_t *fb, uint32_t disp_w, uint32_t disp_h,
                          const char *path)
{
    FILE *fp = fopen(path, "wb");
    if (!fp)
        return -1;

    fprintf(fp, "P6\n%u %u\n255\n", disp_w, disp_h);

    for (uint32_t y = 0; y < disp_h; y++) {
        const uint8_t *row = fb->map + y * fb->stride;
        for (uint32_t x = 0; x < disp_w; x++) {
            const uint8_t *p = row + x * BPP;
            uint8_t rgb[3] = { p[2], p[1], p[0] };
            if (fwrite(rgb, 1, sizeof(rgb), fp) != sizeof(rgb)) {
                fclose(fp);
                return -1;
            }
        }
    }

    if (fclose(fp) != 0)
        return -1;

    return 0;
}

static void maybe_save_snapshot(const drm_buf_t *fb, uint32_t disp_w, uint32_t disp_h,
                                int display_num, int snapshot_interval,
                                const char *snapshot_dir)
{
    if (snapshot_interval <= 0)
        return;

    if (display_num <= 0 || (display_num % snapshot_interval) != 0)
        return;

    if (ensure_dir_exists(snapshot_dir) < 0) {
        fprintf(stderr, "\nwarning: could not create snapshot dir '%s': %s\n",
                snapshot_dir, strerror(errno));
        return;
    }

    char path[512];
    snprintf(path, sizeof(path), "%s/flow_%06d.ppm", snapshot_dir, display_num);

    if (save_fb_to_ppm(fb, disp_w, disp_h, path) < 0) {
        fprintf(stderr, "\nwarning: could not save snapshot '%s': %s\n",
                path, strerror(errno));
        return;
    }

    fprintf(stderr, "\nsaved snapshot: %s\n", path);
}

/* ------------------------------------------------------------------ */
/*  Timing                                                            */
/* ------------------------------------------------------------------ */

static uint64_t now_us(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

/* ------------------------------------------------------------------ */
/*  Main                                                              */
/* ------------------------------------------------------------------ */

int main(int argc, char *argv[])
{
    int max_displays = -1;
    float weight = DEFAULT_FLOW_WEIGHT;
    const char *drm_dev = DRM_DEV;
    const char *flow_dev = FLOW_DEV;
    int opt;
    int print_power = 0;
    int snapshot_interval = DEFAULT_SNAPSHOT_INTERVAL;
    const char *snapshot_dir = DEFAULT_SNAPSHOT_DIR;

    while ((opt = getopt(argc, argv, "n:w:d:f:p:s:o:")) != -1) {
        switch (opt) {
        case 'n': max_displays = atoi(optarg);   break;
        case 'w': weight = strtof(optarg, NULL);  break;
        case 'd': drm_dev = optarg;               break;
        case 'f': flow_dev = optarg;              break;
        case 'p': print_power = atoi(optarg);            break;
        case 's': snapshot_interval = atoi(optarg);       break;
        case 'o': snapshot_dir = optarg;                  break;
        default:
            fprintf(stderr,
                "Usage: %s [-n displays] [-w weight] "
                "[-d drm_dev] [-f flow_dev] [-p 0|1] "
                "[-s snapshot_interval] [-o snapshot_dir]\n", argv[0]);
            return 1;
        }
    }

    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = on_signal;
    sa.sa_flags = 0;
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTERM, &sa, NULL);

    make_colorwheel();

    int flow_fd = open(flow_dev, O_RDONLY);
    if (flow_fd < 0) {
        perror("open flow");
        return 1;
    }

    flow_drm_ctx_t drm;
    memset(&drm, 0, sizeof(drm));
    drm.fd = open(drm_dev, O_RDWR | O_CLOEXEC);
    if (drm.fd < 0) {
        perror("open drm");
        close(flow_fd);
        return 1;
    }
    drmSetMaster(drm.fd);

    if (find_display(&drm, 1920, 1080) < 0) {
        close(drm.fd); close(flow_fd);
        return 1;
    }

    uint32_t disp_w = drm.mode.hdisplay;
    uint32_t disp_h = drm.mode.vdisplay;

    for (int i = 0; i < 2; i++) {
        if (create_fb(drm.fd, disp_w, disp_h, &drm.bufs[i]) < 0) {
            close(drm.fd); close(flow_fd);
            return 1;
        }
    }

    drmModeCrtc *orig = drmModeGetCrtc(drm.fd, drm.crtc_id);
    drmModeSetCrtc(drm.fd, drm.crtc_id, drm.bufs[0].fb_id,
                   0, 0, &drm.conn_id, 1, &drm.mode);

    uint8_t *dma_buf = malloc(MAX_FRAME_SIZE);
    if (!dma_buf) {
        perror("malloc");
        close(drm.fd); close(flow_fd);
        return 1;
    }

    fprintf(stderr, "Running: weight=%.6f, display=%ux%u, scale=%d, snapshots every %d display(s) -> %s\n",
            weight, disp_w, disp_h, SCALE, snapshot_interval, snapshot_dir);
    fprintf(stderr, "Press Ctrl+C to stop.\n\n");

    int display_num = 0;
    int dma_frame_num = 0;
    int last_ts = -1;
    uint64_t t_start = now_us();
    uint64_t fps_time = t_start;
    int fps_count = 0;
    float current_fps = 0.0f;
    int current_power = -1;
    uint64_t last_power_time = 0;

    acc_reset();

    while (!g_quit) {
        if (max_displays >= 0 && display_num >= max_displays)
            break;

        ssize_t n = read(flow_fd, dma_buf, MAX_FRAME_SIZE);
        if (n < 0) {
            if (errno == EINTR) continue;
            perror("read");
            break;
        }
        if (n == 0) break;

        dma_frame_num++;

        int ts = acc_add_frame(dma_buf, n);
        if (ts < 0) continue;

        if (ts <= last_ts && last_ts >= 0) {
            drm_buf_t *fb = &drm.bufs[drm.front];
            render_flow(fb, disp_w, disp_h, weight,
                        current_fps, current_power);
            drmModeSetCrtc(drm.fd, drm.crtc_id, fb->fb_id,
                           0, 0, &drm.conn_id, 1, &drm.mode);
            drm.front ^= 1;
            display_num++;
            maybe_save_snapshot(fb, disp_w, disp_h, display_num,
                                snapshot_interval, snapshot_dir);
            //fps_count++;
            acc_reset();
        }

        last_ts = ts;

        if (ts == NUM_TIMESTEPS) {
            drm_buf_t *fb = &drm.bufs[drm.front];
            render_flow(fb, disp_w, disp_h, weight,
                        current_fps, current_power);
            drmModeSetCrtc(drm.fd, drm.crtc_id, fb->fb_id,
                           0, 0, &drm.conn_id, 1, &drm.mode);
            drm.front ^= 1;
            display_num++;
            maybe_save_snapshot(fb, disp_w, disp_h, display_num,
                                snapshot_interval, snapshot_dir);
            fps_count++;
            acc_reset();
            last_ts = -1;
        }

        /* Update FPS and power every 2 seconds */
        uint64_t now = now_us();
        if (now - fps_time >= 2000000) {
            current_fps = fps_count * 1e6f / (float)(now - fps_time);
            fps_count = 0;
            fps_time = now;

            fprintf(stderr, "\rdisplay %d | dma %d | ts=%d | %.1f fps  ",
                    display_num, dma_frame_num, ts, current_fps);
        }

        /* Update power every 5 seconds (popen is slow) */
        if (now - last_power_time >= 5000000 && print_power) {
            current_power = read_power_mw();
            last_power_time = now;
        }
    }

    double elapsed = (now_us() - t_start) / 1e6;
    fprintf(stderr, "\nDone. %d display frames, %d DMA frames in %.1fs\n",
            display_num, dma_frame_num, elapsed);

    if (orig) {
        drmModeSetCrtc(drm.fd, orig->crtc_id, orig->buffer_id,
                       orig->x, orig->y,
                       &drm.conn_id, 1, &orig->mode);
        drmModeFreeCrtc(orig);
    }

    for (int i = 0; i < 2; i++)
        destroy_fb(drm.fd, &drm.bufs[i]);
    drmDropMaster(drm.fd);
    close(drm.fd);
    free(dma_buf);
    close(flow_fd);
    return 0;
}