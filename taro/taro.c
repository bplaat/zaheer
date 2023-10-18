// clang --target=wasm32 -Wl,--no-entry -Wl,--initial-memory=1048576 -nostdlib -Os taro.c -o taro.wasm

#include <stdbool.h>
#include <stdint.h>

#define CMD_DONE 0
#define CMD_SET_FRAMEBUFFER 1
#define CMD_SET_CLIP 2
#define CMD_CLEAR 3
#define CMD_TRIANGLE 4
#define CMD_TRIANGLE_TEXTURED 5

#define MIN(a, b) (((a) < (b)) ? (a) : (b))
#define MAX(a, b) (((a) > (b)) ? (a) : (b))

typedef struct {
    int16_t x;
    int16_t y;
} vec2_t;

bool is_top_left(vec2_t *start, vec2_t *end) {
    vec2_t edge = {end->x - start->x, end->y - start->y};
    return edge.y < 0 || (edge.y == 0 && edge.x > 0);
}

int32_t edge_cross(vec2_t *a, vec2_t *b, vec2_t *p) {
    vec2_t ab = {b->x - a->x, b->y - a->y};
    vec2_t ap = {p->x - a->x, p->y - a->y};
    return ab.x * ap.y - ab.y * ap.x;
}

__attribute__((export_name("clock"))) void clock(uint8_t *c) {
    uint16_t *framebuffer = 0;
    uint16_t framebuffer_stride = 0;
    uint16_t clip_top = 0;
    uint16_t clip_left = 0;
    uint16_t clip_right = 0;
    uint16_t clip_bottom = 0;

    for (;;) {
        uint8_t cmd = *c++;

        if (cmd == CMD_DONE) {
            return;
        }

        if (cmd == CMD_SET_FRAMEBUFFER) {
            framebuffer = (uint16_t *)*(uint32_t *)c;
            c += 4;
            framebuffer_stride = *(uint16_t *)c;
            c += 2;
            continue;
        }

        if (cmd == CMD_SET_CLIP) {
            clip_top = *(uint16_t *)c;
            c += 2;
            clip_left = *(uint16_t *)c;
            c += 2;
            clip_right = *(uint16_t *)c;
            c += 2;
            clip_bottom = *(uint16_t *)c;
            c += 2;
            continue;
        }

        if (cmd == CMD_CLEAR) {
            uint16_t rgb = *(int16_t *)c;
            c += 2;
            for (int16_t y = clip_top; y <= clip_bottom; y++) {
                for (int16_t x = clip_left; x <= clip_right; x++) {
                    framebuffer[y * framebuffer_stride + x] = rgb;
                }
            }
            continue;
        }

        if (cmd == CMD_TRIANGLE || cmd == CMD_TRIANGLE_TEXTURED) {
            uint16_t *texture;
            uint8_t texture_stride;
            if (cmd == CMD_TRIANGLE_TEXTURED) {
                texture = (uint16_t *)*(uint32_t *)c;
                c += 4;
                texture_stride = *c++;
            }

            vec2_t v0;
            v0.x = *(int16_t *)c;
            c += 2;
            v0.y = *(int16_t *)c;
            c += 2;
            uint16_t v0rgb = *(uint16_t *)c;
            c += 2;
            uint8_t v0r = v0rgb & 31;
            uint8_t v0g = (v0rgb >> 5) & 63;
            uint8_t v0b = (v0rgb >> 11) & 31;
            uint8_t v0u = cmd == CMD_TRIANGLE_TEXTURED ? *c++ : 0;
            uint8_t v0v = cmd == CMD_TRIANGLE_TEXTURED ? *c++ : 0;

            vec2_t v1;
            v1.x = *(int16_t *)c;
            c += 2;
            v1.y = *(int16_t *)c;
            c += 2;
            uint16_t v1rgb = *(uint16_t *)c;
            c += 2;
            uint8_t v1r = v1rgb & 31;
            uint8_t v1g = (v1rgb >> 5) & 63;
            uint8_t v1b = (v1rgb >> 11) & 31;
            uint8_t v1u = cmd == CMD_TRIANGLE_TEXTURED ? *c++ : 0;
            uint8_t v1v = cmd == CMD_TRIANGLE_TEXTURED ? *c++ : 0;

            vec2_t v2;
            v2.x = *(int16_t *)c;
            c += 2;
            v2.y = *(int16_t *)c;
            c += 2;
            uint16_t v2rgb = *(uint16_t *)c;
            c += 2;
            uint8_t v2r = v2rgb & 31;
            uint8_t v2g = (v2rgb >> 5) & 63;
            uint8_t v2b = (v2rgb >> 11) & 31;
            uint8_t v2u = cmd == CMD_TRIANGLE_TEXTURED ? *c++ : 0;
            uint8_t v2v = cmd == CMD_TRIANGLE_TEXTURED ? *c++ : 0;

            int16_t x_min = MIN(MAX(MIN(MIN(v0.x, v1.x), v2.x), clip_left), clip_right);
            int16_t y_min = MIN(MAX(MIN(MIN(v0.y, v1.y), v2.y), clip_top), clip_bottom);
            int16_t x_max = MIN(MAX(MAX(MAX(v0.x, v1.x), v2.x), clip_left), clip_right);
            int16_t y_max = MIN(MAX(MAX(MAX(v0.y, v1.y), v2.y), clip_top), clip_bottom);

            int16_t delta_w0_row = v2.x - v1.x;
            int16_t delta_w1_row = v0.x - v2.x;
            int16_t delta_w2_row = v1.x - v0.x;

            int16_t delta_w0_col = v1.y - v2.y;
            int16_t delta_w1_col = v2.y - v0.y;
            int16_t delta_w2_col = v0.y - v1.y;

            vec2_t p0 = {x_min, y_min};
            int32_t w0_row = edge_cross(&v1, &v2, &p0) + (is_top_left(&v1, &v2) ? 0 : -1);
            int32_t w1_row = edge_cross(&v2, &v0, &p0) + (is_top_left(&v2, &v0) ? 0 : -1);
            int32_t w2_row = edge_cross(&v0, &v1, &p0) + (is_top_left(&v0, &v1) ? 0 : -1);

            int32_t area = edge_cross(&v0, &v1, &v2);

            for (int16_t y = y_min; y <= y_max; y++) {
                int32_t w0 = w0_row;
                int32_t w1 = w1_row;
                int32_t w2 = w2_row;
                for (int16_t x = x_min; x <= x_max; x++) {
                    if ((w0 <= 0 && w1 <= 0 && w2 <= 0) || (w0 >= 0 && w1 >= 0 && w2 >= 0)) {
                        uint8_t alpha = area != 0 ? (w0 << 8) / area : 0;
                        uint8_t beta = area != 0 ? (w1 << 8) / area : 0;
                        uint8_t gamma = area != 0 ? (w2 << 8) / area : 0;

                        uint8_t cr = (alpha * v0r + beta * v1r + gamma * v2r) >> 8;
                        uint8_t cg = (alpha * v0g + beta * v1g + gamma * v2g) >> 8;
                        uint8_t cb = (alpha * v0b + beta * v1b + gamma * v2b) >> 8;

                        uint8_t tr = 31;
                        uint8_t tg = 63;
                        uint8_t tb = 31;
                        if (cmd == CMD_TRIANGLE_TEXTURED) {
                            uint8_t u = (alpha * v0u + beta * v1u + gamma * v2u) >> 8;
                            uint8_t v = (alpha * v0v + beta * v1v + gamma * v2v) >> 8;
                            uint16_t trgb = texture[v * texture_stride + u];
                            tr = trgb & 31;
                            tg = (trgb >> 5) & 63;
                            tb = (trgb >> 11) & 31;
                        }

                        framebuffer[y * framebuffer_stride + x] = (cr * tr >> 5) | (((cg * tg) >> 6) << 5) | (((cb * tb) >> 5) << 11);
                    }

                    w0 += delta_w0_col;
                    w1 += delta_w1_col;
                    w2 += delta_w2_col;
                }
                w0_row += delta_w0_row;
                w1_row += delta_w1_row;
                w2_row += delta_w2_row;
            }
            continue;
        }
    }
}
